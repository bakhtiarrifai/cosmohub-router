#!/usr/bin/env node
// CosmosHub router: a local proxy (127.0.0.1 only) between Claude Code / Codex and CosmosHub.
// - Picks the model from a per-slot fallback chain (config.json), skipping models CosmosHub doesn't list
//   and models that recently failed, and retries the next one when CosmosHub says a model is unavailable.
// - When CosmosHub refuses for billing reasons (balance empty, key revoked), it records that in
//   ~/.cosmohub/exhausted.json so the launcher (cosmohub.ps1) can resume the session on the subscription.
// No dependencies. The CosmosHub key is read from COSMOSHUB_API_KEY and never logged.
import http from "node:http";
import { appendFileSync, existsSync, mkdirSync, readFileSync, renameSync, rmSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { Readable } from "node:stream";
import { randomBytes } from "node:crypto";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const CONFIG = JSON.parse(readFileSync(join(HERE, "config.json"), "utf8"));
const UPSTREAM = CONFIG.upstream.replace(/\/+$/, "");
const PORT = Number(process.env.COSMOHUB_PORT ?? CONFIG.port);
const COOLDOWN_MS = CONFIG.cooldownSeconds * 1000;

const STATE_DIR = join(homedir(), ".cosmohub");
const TOKEN_FILE = join(STATE_DIR, "router-token");
const EXHAUSTED_FILE = join(STATE_DIR, "exhausted.json");
const LOG_FILE = join(STATE_DIR, "router.log");

const KEY = process.env.COSMOSHUB_API_KEY;
if (!KEY) {
  console.error("cosmohub-router: COSMOSHUB_API_KEY is not set");
  process.exit(1);
}

mkdirSync(STATE_DIR, { recursive: true });
if (existsSync(LOG_FILE) && statSync(LOG_FILE).size > 5 * 1024 * 1024) renameSync(LOG_FILE, LOG_FILE + ".old");

// Local token so only the launcher's tools (not any process or web page) can spend the balance.
let TOKEN = existsSync(TOKEN_FILE) ? readFileSync(TOKEN_FILE, "utf8").trim() : "";
if (!TOKEN) {
  TOKEN = "hub-" + randomBytes(24).toString("hex");
  writeFileSync(TOKEN_FILE, TOKEN);
}

const log = (line) => {
  try { appendFileSync(LOG_FILE, `${new Date().toISOString()} ${line}\n`); } catch {}
};

// ---------- model availability ----------

let available = null; // Set of model ids CosmosHub lists, or null when unknown
let lastRefresh = 0;
const cooldown = new Map(); // model id -> epoch ms until which it is skipped

async function refreshModels() {
  try {
    const r = await fetch(`${UPSTREAM}/v1/models`, {
      headers: { authorization: `Bearer ${KEY}`, "accept-encoding": "identity" },
      signal: AbortSignal.timeout(15000),
    });
    const text = await r.text();
    if (!r.ok) return { ok: false, status: r.status, text };
    const j = JSON.parse(text);
    available = new Set((j.data ?? j).map((m) => m.id));
    lastRefresh = Date.now();
    // A model that came back on the list is worth trying again.
    for (const id of cooldown.keys()) if (available.has(id)) cooldown.delete(id);
    return { ok: true, status: r.status };
  } catch (e) {
    return { ok: false, status: 0, text: String(e?.message ?? e) };
  }
}

// "claude-opus*" expands to every listed model with that prefix, newest first.
function expand(pattern) {
  if (pattern.endsWith("*")) {
    if (!available) return [];
    const prefix = pattern.slice(0, -1);
    return [...available].filter((id) => id.startsWith(prefix)).sort((a, b) => b.localeCompare(a, undefined, { numeric: true }));
  }
  if (available && !available.has(pattern)) return [];
  return [pattern];
}

function slotFor(model) {
  const m = model.toLowerCase();
  const direct = Object.keys(CONFIG.chains).find((k) => m === k || m === `hub-${k}`);
  if (direct) return direct;
  return ["opus", "sonnet", "haiku"].find((k) => m.includes(k)) ?? null;
}

function chainFor(model) {
  const slot = slotFor(model);
  const patterns = slot ? CONFIG.chains[slot] : [model, ...CONFIG.chains[CONFIG.defaultChain]];
  const out = [];
  for (const p of patterns) for (const id of expand(p)) if (!out.includes(id)) out.push(id);
  return out;
}

// ---------- error classification ----------

const BILLING_RE = /balance|saldo|credit|quota|insufficient|top.?up|billing|payment|kredit/i;

function classify(status, text) {
  if (status === 402 || status === 401 || status === 403) return "exhausted";
  if (status === 429 && BILLING_RE.test(text)) return "exhausted";
  if (status === 404) {
    // A missing endpoint ("Unknown endpoint: ... Supported endpoints: /v1/models") is not a missing model.
    if (/unknown endpoint|supported endpoints/i.test(text)) return "final";
    return /model .*(does not exist|not available|not found|unavailable)|no such model/i.test(text) ? "next" : "final";
  }
  if ([408, 409, 425, 429, 500, 502, 503, 504, 520, 522, 524, 529].includes(status)) return "next";
  if (status === 400 && /model|not support|unsupported|unavailable|maintenance/i.test(text)) return "next";
  return "final";
}

function readExhausted() {
  try { return JSON.parse(readFileSync(EXHAUSTED_FILE, "utf8")); } catch { return null; }
}

function recordExhausted(status, text) {
  writeFileSync(EXHAUSTED_FILE, JSON.stringify({ at: Date.now(), status, message: String(text).slice(0, 300) }, null, 2));
}

const isAnthropic = (path) => path.startsWith("/v1/messages");

function errorPayload(path, kind, message) {
  if (isAnthropic(path)) {
    return { type: "error", error: { type: kind === "exhausted" ? "permission_error" : "overloaded_error", message } };
  }
  const code = kind === "exhausted" ? "insufficient_quota" : "server_error";
  return { error: { message, type: code, code } };
}

// ---------- HTTP plumbing ----------

function sendJson(res, status, obj) {
  if (res.headersSent) return res.end();
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(obj));
}

const HOP = new Set(["content-encoding", "content-length", "transfer-encoding", "connection", "keep-alive"]);

function pipeResponse(r, res) {
  const headers = {};
  r.headers.forEach((v, k) => { if (!HOP.has(k)) headers[k] = v; });
  res.writeHead(r.status, headers);
  if (!r.body) return res.end();
  Readable.fromWeb(r.body).on("error", () => res.destroy()).pipe(res);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => resolve(Buffer.concat(chunks)));
    req.on("error", reject);
  });
}

const PASS_HEADERS = ["content-type", "accept", "anthropic-version", "anthropic-beta", "openai-beta", "user-agent"];

function upstream(req, pathAndQuery, body, signal) {
  const headers = { authorization: `Bearer ${KEY}`, "accept-encoding": "identity" };
  for (const h of PASS_HEADERS) if (req.headers[h]) headers[h] = req.headers[h];
  if (isAnthropic(pathAndQuery)) headers["x-api-key"] = KEY;
  const hasBody = !["GET", "HEAD"].includes(req.method);
  return fetch(UPSTREAM + pathAndQuery, { method: req.method, headers, body: hasBody ? body : undefined, signal });
}

function localToken(req) {
  return req.headers["x-api-key"] || String(req.headers.authorization ?? "").replace(/^Bearer\s+/i, "");
}

// Tiny paid request, only used to confirm a balance that was empty has been topped up.
async function probeBalance() {
  const model = chainFor("haiku")[0] ?? "deepseek-v4-flash";
  try {
    const r = await fetch(`${UPSTREAM}/v1/chat/completions`, {
      method: "POST",
      headers: { authorization: `Bearer ${KEY}`, "content-type": "application/json", "accept-encoding": "identity" },
      body: JSON.stringify({ model, max_tokens: 16, messages: [{ role: "user", content: "Reply with: ok" }] }),
      signal: AbortSignal.timeout(30000),
    });
    const text = await r.text();
    return { ok: r.ok || classify(r.status, text) !== "exhausted", status: r.status };
  } catch (e) {
    return { ok: false, status: 0 };
  }
}

async function health(res, live) {
  const out = { ok: true, port: PORT, models: available ? available.size : null, lastRefresh, usable: true, reason: "ok" };
  if (live) {
    const m = await refreshModels();
    if (!m.ok) {
      out.usable = false;
      out.reason = m.status ? `CosmosHub returned ${m.status} for /v1/models` : `CosmosHub unreachable (${m.text})`;
      if (classify(m.status, m.text ?? "") === "exhausted") recordExhausted(m.status, m.text);
    } else if (readExhausted()) {
      const p = await probeBalance();
      if (p.ok) rmSync(EXHAUSTED_FILE, { force: true });
      else { out.usable = false; out.reason = `CosmosHub balance still empty (status ${p.status})`; }
    }
  }
  out.exhaustedAt = readExhausted()?.at ?? null;
  out.models = available ? available.size : null;
  sendJson(res, 200, out);
}

// ---------- request handling ----------

async function handle(req, res) {
  const url = new URL(req.url, "http://127.0.0.1");
  if (req.method === "GET" && url.pathname === "/health") return health(res, url.searchParams.has("live"));

  if (localToken(req) !== TOKEN) {
    return sendJson(res, 401, errorPayload(url.pathname, "auth", "cosmohub-router: wrong or missing local token"));
  }

  const ac = new AbortController();
  res.on("close", () => { if (!res.writableEnded) ac.abort(); });

  const pathAndQuery = url.pathname + url.search;
  const raw = await readBody(req);
  let json = null;
  if (raw.length) { try { json = JSON.parse(raw.toString("utf8")); } catch {} }

  // Anything without a model (e.g. GET /v1/models) goes straight through once.
  if (!json || typeof json.model !== "string") {
    const r = await upstream(req, pathAndQuery, raw.length ? raw : undefined, ac.signal);
    return pipeResponse(r, res);
  }

  const requested = json.model;
  const chain = chainFor(requested);
  if (!chain.length) {
    return sendJson(res, 503, errorPayload(url.pathname, "unavailable", `cosmohub-router: no CosmosHub model available for '${requested}'`));
  }
  const now = Date.now();
  let candidates = chain.filter((id) => (cooldown.get(id) ?? 0) <= now);
  if (!candidates.length) candidates = chain; // everything is cooling down: try anyway rather than fail outright

  let last = null;
  for (const id of candidates) {
    json.model = id;
    let r;
    try {
      r = await upstream(req, pathAndQuery, JSON.stringify(json), ac.signal);
    } catch (e) {
      if (ac.signal.aborted) return;
      log(`${url.pathname} ${requested} -> ${id} NETWORK ${e?.message ?? e}`);
      cooldown.set(id, Date.now() + COOLDOWN_MS);
      last = { status: 0, text: String(e?.message ?? e) };
      continue;
    }

    if (r.ok) {
      log(`${url.pathname} ${requested} -> ${id} ${r.status}`);
      return pipeResponse(r, res);
    }

    const text = await r.text();
    const kind = classify(r.status, text);
    log(`${url.pathname} ${requested} -> ${id} ${r.status} ${kind} ${text.slice(0, 160).replace(/\s+/g, " ")}`);

    if (kind === "exhausted") {
      recordExhausted(r.status, text);
      const msg = `CosmosHub refused the request (${r.status}: ${text.slice(0, 160)}). The balance is probably empty. ` +
        "Exit this session (/exit or Ctrl+C) and the cosmohub launcher will resume it on your subscription.";
      return sendJson(res, isAnthropic(url.pathname) ? 403 : 429, errorPayload(url.pathname, "exhausted", msg));
    }
    if (kind === "final") {
      res.writeHead(r.status, { "content-type": r.headers.get("content-type") ?? "application/json" });
      return res.end(text);
    }
    cooldown.set(id, Date.now() + (r.status === 404 ? COOLDOWN_MS * 5 : COOLDOWN_MS));
    last = { status: r.status, text };
  }

  sendJson(res, 503, errorPayload(url.pathname, "unavailable",
    `cosmohub-router: every model for '${requested}' is unavailable (${candidates.join(", ")}). ` +
    `Last error: ${last?.status} ${String(last?.text ?? "").slice(0, 200)}`));
}

const server = http.createServer((req, res) => {
  handle(req, res).catch((e) => {
    log(`ERROR ${req.method} ${req.url} ${e?.stack ?? e}`);
    sendJson(res, 502, errorPayload(req.url ?? "", "unavailable", `cosmohub-router: ${e?.message ?? e}`));
  });
});
server.requestTimeout = 0; // long streaming responses
server.on("error", (e) => {
  if (e.code === "EADDRINUSE") process.exit(0); // another router is already serving
  console.error(e);
  process.exit(1);
});

await refreshModels();
setInterval(refreshModels, CONFIG.modelRefreshSeconds * 1000);
server.listen(PORT, "127.0.0.1", () => log(`listening on 127.0.0.1:${PORT}, ${available ? available.size : "?"} models`));

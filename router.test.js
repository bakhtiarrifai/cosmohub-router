import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";
import { once } from "node:events";
import http from "node:http";
import { setTimeout as delay } from "node:timers/promises";
import test from "node:test";

const config = JSON.parse(readFileSync(new URL("./config.json", import.meta.url), "utf8"));
const readme = readFileSync(new URL("./README.md", import.meta.url), "utf8");

test("router sends upstream requests to the current CosmosHub API", () => {
  assert.equal(config.upstream, "https://api.cosmosin.io");
});

test("documentation does not use the retired API domain", () => {
  assert.equal(readme.includes("api.cosmoshub.tech"), false);
});

test("model control, routing status, strict pinning, and persistence (mock upstream only)", async (t) => {
  const dir = mkdtempSync(join(tmpdir(), "cosmohub-test-"));
  const calls = [];
  let failures = new Map();
  let listed = ["primary", "backup", "cheap", "claude-opus-test"];
  const upstream = http.createServer(async (req, res) => {
    if (req.url === "/v1/models") {
      res.writeHead(200, { "content-type": "application/json" });
      return res.end(JSON.stringify({ data: listed.map((id) => ({ id })) }));
    }
    let body = "";
    for await (const chunk of req) body += chunk;
    const data = JSON.parse(body);
    calls.push(data.model);
    res.writeHead(failures.get(data.model) ?? 200, { "content-type": "application/json" });
    res.end(JSON.stringify({ model: data.model, content: [{ type: "text", text: "ok" }] }));
  });
  await new Promise((resolve) => upstream.listen(0, "127.0.0.1", resolve));
  // Reserve a free port for the child router.
  const reservation = http.createServer();
  await new Promise((resolve) => reservation.listen(0, "127.0.0.1", resolve));
  const port = reservation.address().port;
  await new Promise((resolve) => reservation.close(resolve));
  const conf = join(dir, "config.json");
  writeFileSync(conf, JSON.stringify({
    ...config, upstream: `http://127.0.0.1:${upstream.address().port}`, port,
    modelRefreshSeconds: 3600, defaultChain: "codex",
    chains: { opus: ["primary", "backup"], sonnet: ["primary", "backup"], haiku: ["cheap"], codex: ["primary", "backup"] },
  }));
  let child;
  let stderr = "";
  const base = `http://127.0.0.1:${port}`;
  async function start() {
    child = spawn(process.execPath, [fileURLToPath(new URL("./router.js", import.meta.url))], {
      env: { ...process.env, COSMOSHUB_API_KEY: "mock-key", COSMOHUB_CONFIG: conf, COSMOHUB_STATE_DIR: dir, COSMOHUB_PORT: String(port) },
      stdio: ["ignore", "ignore", "pipe"],
    });
    child.stderr.on("data", (c) => { stderr += c; });
    for (let i = 0; i < 100; i++) {
      if (child.exitCode !== null) throw new Error(`Router exited: ${stderr}`);
      try { if ((await fetch(base + "/health")).ok) return; } catch {}
      await delay(50);
    }
    throw new Error(`Router startup timeout: ${stderr}`);
  }
  async function stop() {
    if (child && child.exitCode === null) { const exited = once(child, "exit"); child.kill(); await exited; }
  }
  t.after(async () => {
    await stop();
    await new Promise((resolve) => upstream.close(resolve));
    rmSync(dir, { recursive: true, force: true });
  });
  await start();
  const token = readFileSync(join(dir, "router-token"), "utf8").trim();
  const headers = { authorization: `Bearer ${token}`, "content-type": "application/json" };
  const status = async () => (await fetch(base + "/router/models", { headers })).json();
  const select = (slot, model) => fetch(base + "/router/models", { method: "POST", headers, body: JSON.stringify({ slot, model }) });
  const generate = (model = "hub-opus", path = "/v1/messages") => fetch(base + path, {
    method: "POST", headers, body: JSON.stringify({ model, messages: [{ role: "user", content: "test" }] }),
  });

  assert.equal((await fetch(base + "/router/models")).status, 401);
  assert.equal((await fetch(base + "/router/models", { method: "POST", headers: { "content-type": "application/json" }, body: '{"slot":"opus","model":"backup"}' })).status, 401);
  assert.equal((await status()).slots.opus.mode, "auto");
  assert.equal((await status()).lastRoute, null);
  failures.set("primary", 503);
  const first = await generate();
  assert.equal(first.status, 200);
  assert.equal(first.headers.get("x-cosmohub-model"), "backup");
  assert.deepEqual(calls, ["primary", "backup"]);
  assert.equal((await status()).slots.opus.lastRoute.model, "backup");
  const last = (await status()).lastRoute;
  await generate("hub-haiku", "/v1/messages/count_tokens");
  assert.deepEqual((await status()).lastRoute, last);

  assert.equal((await select("opus", "backup")).status, 200);
  assert.equal((await status()).slots.opus.mode, "manual");
  assert.equal((await select("opus", "not-listed")).status, 400);
  assert.equal((await select("invalid", "backup")).status, 400);
  assert.equal((await select("opus", "backup*")).status, 400);
  assert.equal((await status()).slots.opus.selectedModel, "backup");
  failures.set("backup", 503);
  calls.length = 0;
  assert.equal((await generate()).status, 503);
  assert.deepEqual(calls, ["backup"]); // no silent fallback in manual mode
  assert.equal((await status()).lastRoute.model, "backup"); // failed attempts do not claim success

  failures.clear();
  await stop();
  await start();
  assert.equal((await status()).slots.opus.selectedModel, "backup");
  assert.equal((await status()).lastRoute, null); // old session is not presented as active
  listed = listed.filter((id) => id !== "backup");
  await select("haiku", "cheap"); // refresh list: an existing pin still must not silently switch
  calls.length = 0;
  const pinned = await generate();
  assert.equal(pinned.headers.get("x-cosmohub-mode"), "manual");
  assert.deepEqual(calls, ["backup"]);
  assert.equal((await generate("hub-model/claude-opus-test")).headers.get("x-cosmohub-model"), "claude-opus-test");

  await select("opus", null);
  calls.length = 0;
  assert.equal((await generate()).headers.get("x-cosmohub-model"), "primary");
  assert.deepEqual(calls, ["primary"]);
  assert.equal((await status()).slots.opus.mode, "auto");
  await select("codex", "cheap");
  assert.equal((await generate("gpt-request", "/v1/responses")).headers.get("x-cosmohub-model"), "cheap");
  assert.equal((await status()).slots.codex.lastRoute.model, "cheap");
  assert.equal((await generate("hub-sonnet")).headers.get("x-cosmohub-model"), "primary"); // slot isolation

  if (process.platform === "win32") {
    // Execute the actual PowerShell helpers against the isolated mock router, not the user's router.
    const literal = (s) => "'" + s.replaceAll("'", "''") + "'";
    const script = `
      $ErrorActionPreference = 'Stop'
      . ${literal(fileURLToPath(new URL("./cosmohub.ps1", import.meta.url)))}
      $global:CosmoHubUrl = ${literal(base)}
      $global:CosmoHubState = ${literal(dir)}
      function Start-CosmoHubRouter { return $true }
      cosmohub-model
      cosmohub-model -List
      cosmohub-model opus primary
      if ((Get-CosmoHubModels).slots.opus.selectedModel -ne 'primary') { throw 'Manual selection failed' }
      cosmohub-model opus auto
      if ((Get-CosmoHubModels).slots.opus.mode -ne 'auto') { throw 'Auto reset failed' }
    `;
    const ps = spawn("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", script], { stdio: ["ignore", "pipe", "pipe"] });
    let output = "";
    ps.stdout.on("data", (c) => { output += c; });
    ps.stderr.on("data", (c) => { output += c; });
    const [code] = await once(ps, "exit");
    assert.equal(code, 0, output);
    assert.match(output, /Last successful routing/);
    assert.match(output, /Next request/);
  }
});

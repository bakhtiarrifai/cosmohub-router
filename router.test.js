import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const config = JSON.parse(readFileSync(new URL("./config.json", import.meta.url), "utf8"));
const readme = readFileSync(new URL("./README.md", import.meta.url), "utf8");

test("router sends upstream requests to the current CosmosHub API", () => {
  assert.equal(config.upstream, "https://api.cosmosin.io");
});

test("documentation does not use the retired API domain", () => {
  assert.equal(readme.includes("api.cosmoshub.tech"), false);
});

test("documentation explains how to restart only the router on Windows", () => {
  assert.match(readme, /### Update dan restart router \(Windows\)/);
  assert.match(readme, /git branch --show-current/);
  assert.match(readme, /git stash -u/);
  assert.match(readme, /git pull --ff-only/);
  assert.match(readme, /Get-CimInstance Win32_Process -Filter "Name='node\.exe'"/);
  assert.match(readme, /\$_\.CommandLine -like "\*\$root\*"/);
  assert.match(readme, /\$_\.CommandLine -like "\*router\.js\*"/);
  assert.match(readme, /Stop-Process -Id \$_\.ProcessId/);
  assert.doesNotMatch(readme, /Stop-Process -Name node/);
  assert.match(readme, /Start-Process -FilePath \$node -ArgumentList/);
  assert.match(readme, /health\?live=1/);
});

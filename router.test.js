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

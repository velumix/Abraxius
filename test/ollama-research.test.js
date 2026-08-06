"use strict";
const assert = require("node:assert/strict");
const test = require("node:test");
const { formatResearchContext } = require("../lib/ollama-research");

test("Ollama research context labels web text as untrusted data", () => {
  const text = formatResearchContext({ results: [{ title: "Example", url: "https://example.com" }] });
  assert.match(text, /<abraxius_web_research>/);
  assert.match(text, /untrusted reference data/);
  assert.match(text, /https:\/\/example.com/);
});

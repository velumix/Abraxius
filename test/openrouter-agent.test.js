"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

test("CLI and MCP server expose the controlled OpenRouter agent path", () => {
  const cli = fs.readFileSync(path.join(__dirname, "../cli.js"), "utf8");
  const mcp = fs.readFileSync(path.join(__dirname, "../lib/mcp-server.js"), "utf8");
  assert.match(cli, /case "openrouter"/);
  assert.match(cli, /OPENROUTER_API_KEY/);
  assert.match(mcp, /name: "openrouter_chat"/);
  assert.match(mcp, /OPENROUTER_API_KEY/);
});

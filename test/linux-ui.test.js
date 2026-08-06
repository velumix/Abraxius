"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { runCli } = require("../app/Abraxius.Linux/main");

test("runCli rejects disallowed commands with structured error payload", async () => {
  const result = await runCli(["invalid_command"]);
  assert.equal(result.ok, false);
  assert.equal(result.code, null);
  assert.equal(result.signal, null);
  assert.equal(result.error, "Command is not available in the Linux UI");
  assert.equal(result.command, "abraxius invalid_command");
});

test("runCli returns structured data on execution", async () => {
  const result = await runCli(["status"]);
  assert.equal(typeof result.ok, "boolean");
  assert.equal(result.command, "abraxius status");
  assert.equal(typeof result.stdout, "string");
  assert.equal(typeof result.stderr, "string");
  assert.equal(typeof result.output, "string");
});

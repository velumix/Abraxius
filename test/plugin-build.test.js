const test = require("node:test");
const assert = require("node:assert/strict");
const { buildPluginSource } = require("../scripts/build-plugin");

test("plugin bundle resolves every repository module deterministically", () => {
  const first = buildPluginSource();
  const second = buildPluginSource();
  assert.equal(first, second);
  assert.ok(first.includes("local Pathing = (function()"));
  assert.ok(first.includes("local Inspection = (function()"));
  assert.ok(first.includes("local Export = (function()"));
  assert.ok(first.includes("local Update = (function()"));
  assert.ok(first.includes("local AXL = (function()"));
  assert.ok(first.includes("local Transport = (function()"));
  assert.ok(!first.includes("--#include"));
  assert.ok(!first.includes("require(script.Logger)"));
});

test("plugin bundle preserves command registrations and safety contracts", () => {
  const source = buildPluginSource();
  for (const command of ["read_source", "write_source", "export_scripts", "axl", "execute_luau", "delete_instance", "batch"]) {
    assert.ok(source.includes(`commandHandlers["${command}"]`), command);
  }
  assert.ok(source.includes("Luau execution requires confirm=true"));
  assert.ok(source.includes("Deletion requires confirm=true"));
  assert.ok(source.includes("ChangeHistoryService:TryBeginRecording"));
  assert.ok(source.includes("protocolVersion = 6"));
  assert.ok(source.includes('"axl.core"'));
  assert.ok(source.includes('if pending then " pending=1" else " verified=1"'));
  assert.ok(source.includes("RELEVANT LIVE SCRIPTS"));
  assert.ok(source.includes("taskTerms(taskText)"));
  assert.ok(source.includes("isVendoredPath(lowerPath)"));
  assert.ok(source.includes("termCounts(source, wanted)"));
  assert.ok(source.includes("if pathCoverage == 0 then score = -1"));
  assert.ok(source.includes("if #terms >= 3 then 20 else 1"));
  assert.ok(source.includes("coverage * 20"));
  assert.ok(source.includes('matched=" .. table.concat(item.matchedTerms'));
});

test("plugin output uses the clean Abraxius logging grammar", () => {
  const source = buildPluginSource();
  assert.ok(source.includes('plugin = { icon = emoji(0x1F50C)'));
  assert.ok(source.includes('connect = { icon = emoji(0x2705)'));
  assert.ok(source.includes('local output = cfg.icon .. " " .. clean'));
  assert.ok(source.includes('Logger.plugin("Companion ready (v"'));
  assert.ok(source.includes('Logger.connect("Registered session "'));
  assert.ok(source.includes('lastConnectionLogAt >= 30'));
  assert.doesNotMatch(source, /[\u0080-\uffff]/);
  assert.ok(!source.includes("[Abraxius]"));
});

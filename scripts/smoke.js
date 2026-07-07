const assert = require("assert");
const fs = require("fs");
const os = require("os");
const path = require("path");
const {
  addMemory,
  buildAiContext,
  clearMemory,
  loadMemory,
  toMarkdown,
} = require("../lib/ai-context");
const { MCPContext } = require("../lib/context");
const { PendingPushes, hashSource } = require("../lib/pending");
const { PluginServer } = require("../lib/plugin-server");

function testContext() {
  const context = new MCPContext({ maxRecent: 2 });
  assert.strictEqual(context.normalizePath("game.ServerScriptService.MatchManager"), "ServerScriptService.MatchManager");
  assert.strictEqual(context.normalizePath("/ReplicatedStorage/Config"), "ReplicatedStorage/Config");

  context.touchScript("A");
  context.touchScript("B");
  context.touchScript("C");
  assert.deepStrictEqual(context.recentScripts(), ["C", "B"]);

  context.record({ type: "call", target: "A", datamodel: "Edit", summary: "test" });
  assert.strictEqual(context.lastOperation("call").target, "A");
}

function testPendingPushes() {
  const pending = new PendingPushes();
  const source = "print('hello')";
  const entry = pending.recordPush("ServerScriptService.Test", source);
  assert.strictEqual(entry.sourceHash, hashSource(source));

  const live = pending.verify("ServerScriptService.Test", source);
  assert.strictEqual(live.status, "live");
  assert.strictEqual(live.stale, false);

  const stale = pending.verify("ServerScriptService.Test", "print('changed')");
  assert.strictEqual(stale.status, "stale");
  assert.strictEqual(stale.stale, true);
}

function testPluginEvents() {
  const plugin = new PluginServer({ eventLimit: 3 });
  const received = [];
  plugin.on("event", (event) => received.push(event));

  plugin.recordEvent({ type: "selection_changed", paths: ["A"] });
  plugin.recordEvent({ type: "source_changed", path: "B" });
  plugin.recordEvent({ type: "source_changed", path: "C" });
  plugin.recordEvent({ type: "source_changed", path: "D" });

  assert.strictEqual(received.length, 4);
  assert.strictEqual(plugin.events.length, 3);
  assert.deepStrictEqual(plugin.listEvents({ since: 2 }).map((event) => event.path), ["C", "D"]);
  assert.deepStrictEqual(plugin.listEvents({ limit: 1 }).map((event) => event.path), ["D"]);
}

function testAiContextMemory() {
  const projectDir = fs.mkdtempSync(path.join(os.tmpdir(), "abraxius-smoke-"));
  const { entry } = addMemory(projectDir, {
    text: "Use MatchManager as the round flow source of truth.",
    tags: ["architecture"],
    path: "ServerScriptService.MatchManager",
  });
  const memory = loadMemory(projectDir);
  assert.strictEqual(memory.notes.length, 1);
  assert.strictEqual(memory.notes[0].id, entry.id);

  const snapshot = buildAiContext({ projectDir });
  const markdown = toMarkdown(snapshot);
  assert.ok(markdown.includes("Abraxius AI Context"));
  assert.ok(markdown.includes("MatchManager"));

  const cleared = clearMemory(projectDir, entry.id);
  assert.strictEqual(cleared.notes.length, 0);
}

testContext();
testPendingPushes();
testPluginEvents();
testAiContextMemory();

console.log("Smoke tests passed");

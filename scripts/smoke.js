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
const { RobloxMCPBridge } = require("../bridge");
const { Puller } = require("../lib/pull");

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

  context.ingestStudioEvent({
    type: "context_snapshot",
    snapshot: { mode: "Edit", selection: [], activeScript: null },
  });
  context.ingestStudioEvent({
    type: "source_changed",
    path: "ReplicatedStorage.Test",
    sourceHash: "abc123",
  });
  context.ingestStudioEvent({ type: "history", action: "undo", name: "Rename" });
  context.ingestStudioEvent({ type: "output", level: "MessageError", message: "failed" });
  const snapshot = context.toSnapshot();
  assert.strictEqual(snapshot.studio.mode, "Edit");
  assert.strictEqual(snapshot.studio.lastHistoryCommit.name, "Rename");
  assert.strictEqual(snapshot.recentScripts[0], "ReplicatedStorage.Test");
  assert.strictEqual(snapshot.recentStudioErrors.length, 1);
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

async function postJson(port, route, body) {
  return new Promise((resolve, reject) => {
    const req = require("http").request({
      hostname: "127.0.0.1",
      port,
      path: route,
      method: "POST",
      headers: { "Content-Type": "application/json" },
    }, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => resolve(JSON.parse(data)));
    });
    req.on("error", reject);
    req.end(JSON.stringify(body));
  });
}

async function testOfflineStartupAndSessionRecovery() {
  const bridge = new RobloxMCPBridge({ port: 0 });
  await bridge.start();
  assert.strictEqual(bridge.ready, false);
  assert.ok(bridge.port > 0);
  bridge.stop();

  const plugin = new PluginServer({ port: 0 });
  await plugin.start();
  await postJson(plugin.port, "/plugin/register", { sessionId: "stable" });
  const original = plugin.sessions.get("stable");
  original.commandQueue.push({ id: "queued" });
  await postJson(plugin.port, "/plugin/register", { sessionId: "stable" });
  assert.strictEqual(plugin.sessions.get("stable"), original);
  assert.strictEqual(original.commandQueue.length, 1);
  plugin.stop();
}

async function testBulkPull() {
  const outputDir = fs.mkdtempSync(path.join(os.tmpdir(), "abraxius-pull-"));
  let calls = 0;
  const client = {
    async pluginCall(command) {
      calls++;
      assert.strictEqual(command.type, "export_scripts");
      return {
        ok: true,
        result: {
          ok: true,
          scripts: [
            {
              path: "ServerScriptService.Main",
              className: "Script",
              source: "print('fast')",
              hasChildren: false,
              runContext: "Legacy",
            },
          ],
        },
      };
    },
  };
  const result = await new Puller(client, { outputDir }).pull();
  assert.strictEqual(calls, 1);
  assert.strictEqual(result.stats.scripts, 1);
  assert.strictEqual(
    fs.readFileSync(path.join(outputDir, "src", "ServerScriptService", "Main.server.luau"), "utf8"),
    "print('fast')",
  );
  assert.ok(fs.existsSync(path.join(outputDir, "place.json")));
}

async function main() {
  testContext();
  testPendingPushes();
  testPluginEvents();
  testAiContextMemory();
  await testOfflineStartupAndSessionRecovery();
  await testBulkPull();
  console.log("Smoke tests passed");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});

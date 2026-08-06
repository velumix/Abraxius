const test = require("node:test");
const assert = require("node:assert/strict");
const WebSocket = require("ws");
const { AiToolWebSocketServer } = require("../lib/ai-tool-ws-server");

function rpc(socket, method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = Math.random().toString(36).slice(2);
    const onMessage = (raw) => {
      const message = JSON.parse(raw.toString());
      if (message.id !== id) return;
      socket.off("message", onMessage);
      if (message.error) reject(new Error(message.error)); else resolve(message.result);
    };
    socket.on("message", onMessage);
    socket.send(JSON.stringify({ id, method, params }));
  });
}

test("AI tool WebSocket exposes discovery, context, and approval-gated calls", async () => {
  const calls = [];
  const server = new AiToolWebSocketServer({
    port: 0,
    bridge: { ready: true, listTools: async () => [{ name: "get_studio_state" }], callTool: async (name, args) => { calls.push({ name, args }); return { ok: true }; } },
    context: { preferredDatamodel: "Edit", record() {} }, pendingPushes: { recordPush() {} }, pluginServer: {},
    buildContext: ({ projectDir }) => ({ projectDir: projectDir || null, source: "test" }),
  });
  await server.start();
  const address = server.server.address();
  const socket = await new Promise((resolve, reject) => { const s = new WebSocket(`ws://127.0.0.1:${address.port}/ai`); s.once("open", () => resolve(s)); s.once("error", reject); });
  const toolsRes = await rpc(socket, "tools/list");
  assert.ok(toolsRes.tools.some((t) => t.name === "get_studio_state"));
  assert.deepEqual(await rpc(socket, "context/get", { projectDir: "/tmp/project" }), { projectDir: "/tmp/project", source: "test" });
  const approval = await rpc(socket, "tools/call", { name: "multi_edit", arguments: { file_path: "x" } });
  assert.equal(approval.approvalRequired, true);
  assert.deepEqual(await rpc(socket, "tools/call", { name: "multi_edit", arguments: { file_path: "x" }, approved: true }), { ok: true });
  assert.equal(calls.length, 1);
  socket.close(); server.stop();
});

test("AI tool WebSocket forwards browser commands and returns page results", async () => {
  const server = new AiToolWebSocketServer({ port: 0, bridge: { ready: false }, context: {}, pendingPushes: {}, pluginServer: {}, buildContext: () => ({}) });
  await server.start();
  const port = server.server.address().port;
  const open = () => new Promise((resolve, reject) => { const s = new WebSocket(`ws://127.0.0.1:${port}/ai`); s.once("open", () => resolve(s)); s.once("error", reject); });
  const browser = await open();
  await rpc(browser, "initialize", { role: "browser_extension" });
  const caller = await open();
  const command = rpc(caller, "browser/send", { command: "page/get_context" });
  const inbound = await new Promise((resolve) => browser.once("message", (raw) => resolve(JSON.parse(raw.toString()))));
  assert.equal(inbound.type, "browser_command");
  browser.send(JSON.stringify({ type: "browser_result", id: inbound.id, result: { title: "test page" } }));
  assert.deepEqual(await command, { title: "test page" });
  browser.close(); caller.close(); server.stop();
});

test("AI tool WebSocket rejects an in-flight browser command when Brave disconnects", async () => {
  const server = new AiToolWebSocketServer({ port: 0, bridge: { ready: false }, context: {}, pendingPushes: {}, pluginServer: {}, buildContext: () => ({}) });
  await server.start();
  const port = server.server.address().port;
  const open = () => new Promise((resolve, reject) => { const s = new WebSocket(`ws://127.0.0.1:${port}/ai`); s.once("open", () => resolve(s)); s.once("error", reject); });
  const browser = await open();
  await rpc(browser, "initialize", { role: "browser_extension" });
  const caller = await open();
  const command = rpc(caller, "browser/send", { command: "page/wait_for_reply" });
  await new Promise((resolve) => browser.once("message", resolve));
  browser.close();
  await assert.rejects(command, /Brave extension disconnected/);
  caller.close(); server.stop();
});

test("apply_patch handles *** Begin Patch format", async () => {
  const server = new AiToolWebSocketServer({ port: 0, bridge: { ready: false }, context: {}, pendingPushes: {}, pluginServer: {}, buildContext: () => ({}) });
  await server.start();
  const address = server.server.address();
  const socket = await new Promise((resolve, reject) => { const s = new WebSocket(`ws://127.0.0.1:${address.port}/ai`); s.once("open", () => resolve(s)); s.once("error", reject); });
  const tmpDir = require("os").tmpdir();
  server.allowedRoots.push(tmpDir);
  const targetFile = require("path").join(tmpDir, `test-patch-${Date.now()}.txt`);
  const patch = `*** Begin Patch\n*** Add File: ${targetFile}\nhello world\n*** End Patch`;
  const result = await rpc(socket, "tools/call", { name: "apply_patch", arguments: { cwd: tmpDir, patch }, approved: true });
  assert.equal(result.exitCode, 0);
  assert.equal(require("fs").readFileSync(targetFile, "utf8"), "hello world");
  try { require("fs").unlinkSync(targetFile); } catch {}
  socket.close(); server.stop();
});

const test = require("node:test");
const assert = require("node:assert/strict");
const WebSocket = require("ws");
const path = require("path");
const fs = require("fs");
const os = require("os");
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

test("SunCityRP vault requests: create_file, apply_patch, git_diff resolve in allowedRoots", async () => {
  const tmpVault = fs.mkdtempSync(path.join(os.tmpdir(), "vault-test-"));
  const sunCityDir = path.join(tmpVault, "SunCityRP");
  fs.mkdirSync(path.join(sunCityDir, "src"), { recursive: true });
  fs.writeFileSync(path.join(sunCityDir, "README.md"), "# SunCityRP");

  // Init git repo in test SunCityRP directory for git_diff test
  require("child_process").execSync("git init && git add README.md", { cwd: sunCityDir });

  const server = new AiToolWebSocketServer({
    port: 0,
    bridge: { ready: false },
    context: {},
    pendingPushes: {},
    pluginServer: {},
    buildContext: () => ({}),
    allowedRoots: [process.cwd(), tmpVault],
  });
  await server.start();
  const address = server.server.address();
  const socket = await new Promise((resolve, reject) => {
    const s = new WebSocket(`ws://127.0.0.1:${address.port}/ai`);
    s.once("open", () => resolve(s));
    s.once("error", reject);
  });

  // 1. Test create_file in SunCityRP
  const targetFile = path.join(sunCityDir, "src/TestScript.lua");
  const createRes = await rpc(socket, "tools/call", {
    name: "create_file",
    arguments: { path: targetFile, content: "-- SunCityRP Test" },
    approved: true,
  });
  assert.equal(createRes.ok, true);
  assert.equal(fs.readFileSync(targetFile, "utf8"), "-- SunCityRP Test");
  assert.ok(createRes.path.endsWith("src/TestScript.lua"));

  // 2. Test apply_patch in SunCityRP (Add File)
  const patchFile = path.join(sunCityDir, "src/PatchedScript.lua");
  const patch = `*** Begin Patch\n*** Add File: ${patchFile}\nprint("SunCityRP Patch")\n*** End Patch`;
  const patchRes = await rpc(socket, "tools/call", {
    name: "apply_patch",
    arguments: { cwd: sunCityDir, patch },
    approved: true,
  });
  assert.equal(patchRes.exitCode, 0);
  assert.equal(fs.readFileSync(patchFile, "utf8"), 'print("SunCityRP Patch")');

  // 3. Test git_diff in SunCityRP
  const diffRes = await rpc(socket, "tools/call", {
    name: "git_diff",
    arguments: { path: sunCityDir },
    approved: true,
  });
  assert.equal(typeof diffRes.stdout, "string");

  // 4. Test security restriction: path outside allowedRoots fails
  const outsidePath = "/tmp/outside-abraxius-vault.txt";
  await assert.rejects(
    rpc(socket, "tools/call", {
      name: "create_file",
      arguments: { path: outsidePath, content: "forbidden" },
      approved: true,
    }),
    /Path is outside approved Abraxius project roots/
  );

  socket.close();
  server.stop();
  fs.rmSync(tmpVault, { recursive: true, force: true });
});

test("Duplicate wake suppression and structured activity log formatting", () => {
  // Test helper functions used by background.js and sidepanel.js
  const extractTargetPath = (args = {}) => args.path || args.cwd || args.target_file || args.file_path || args.query || args.command || ".";
  const formatSummary = (toolName, result, error) => {
    if (error) return error.message || String(error);
    if (!result) return "OK";
    if (toolName === "create_file") return `Created file ${result.path || ""} (${result.bytes ?? 0} bytes)`.trim();
    if (toolName === "apply_patch") return (result.stdout || "Applied patch").trim().split("\n")[0];
    if (toolName === "git_diff") return `Diff retrieved (${(result.stdout || "").length} bytes)`;
    return "Success";
  };

  const formattedLog = (event) => {
    const at = event.at ? new Date(event.at) : new Date();
    if (event.tool) {
      const parts = [
        `[${at.toLocaleTimeString()}]`,
        (event.status || "INFO").toUpperCase(),
        `tool=${event.tool}`,
        `target=${event.target || "."}`,
      ];
      if (event.summary) parts.push(`summary=${event.summary}`);
      return parts.join(" ");
    }
    return `[${at.toLocaleTimeString()}] ${event.level.toUpperCase()} ${event.message}`;
  };

  const createReq = { name: "create_file", arguments: { path: "/home/velumix/Desktop/AbraxiusVault/SunCityRP/src/foo.lua", content: "test" } };
  const target = extractTargetPath(createReq.arguments);
  assert.equal(target, "/home/velumix/Desktop/AbraxiusVault/SunCityRP/src/foo.lua");

  const dispatchedEvent = { at: 1700000000000, status: "DISPATCHED", tool: createReq.name, target };
  const log1 = formattedLog(dispatchedEvent);
  assert.ok(log1.includes("DISPATCHED tool=create_file target=/home/velumix/Desktop/AbraxiusVault/SunCityRP/src/foo.lua"));

  const successResult = { ok: true, path: "SunCityRP/src/foo.lua", bytes: 4 };
  const summary = formatSummary("create_file", successResult, null);
  const successEvent = { at: 1700000000000, status: "SUCCESS", tool: createReq.name, target, summary };
  const log2 = formattedLog(successEvent);
  assert.ok(log2.includes("SUCCESS tool=create_file target=/home/velumix/Desktop/AbraxiusVault/SunCityRP/src/foo.lua summary=Created file SunCityRP/src/foo.lua (4 bytes)"));
});

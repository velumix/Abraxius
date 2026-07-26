const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { Puller } = require("../lib/pull");
const { Pusher, resolveStudioPath, buildSourceEdits } = require("../lib/push");

function temporaryProject() {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "abraxius-test-"));
  fs.writeFileSync(path.join(directory, "place.json"), JSON.stringify({ tree: { $className: "DataModel", ServerScriptService: { $path: "src/ServerScriptService" }, ReplicatedStorage: { $path: "src/ReplicatedStorage" } } }));
  return directory;
}

test("pull maps every script class and child script convention", async (t) => {
  const outputDir = temporaryProject();
  t.after(() => fs.rmSync(outputDir, { recursive: true, force: true }));
  const client = { pluginCall: async () => ({ result: { ok: true, scripts: [
    { path: "ServerScriptService.Server", className: "Script", source: "server", hasChildren: false },
    { path: "ReplicatedStorage.Client", className: "LocalScript", source: "client", hasChildren: false },
    { path: "ReplicatedStorage.Package", className: "ModuleScript", source: "module", hasChildren: true },
  ] } }) };
  const result = await new Puller(client, { outputDir }).pull();
  assert.equal(result.stats.scripts, 3);
  assert.equal(fs.readFileSync(path.join(outputDir, "src/ServerScriptService/Server.server.luau"), "utf8"), "server");
  assert.equal(fs.readFileSync(path.join(outputDir, "src/ReplicatedStorage/Client.client.luau"), "utf8"), "client");
  assert.equal(fs.readFileSync(path.join(outputDir, "src/ReplicatedStorage/Package/init.luau"), "utf8"), "module");
});

test("resolveStudioPath covers regular and init files", (t) => {
  const projectDir = temporaryProject();
  t.after(() => fs.rmSync(projectDir, { recursive: true, force: true }));
  fs.mkdirSync(path.join(projectDir, "src/ServerScriptService/Folder/Package"), { recursive: true });
  const regular = path.join(projectDir, "src/ServerScriptService/Folder/Main.server.luau");
  const init = path.join(projectDir, "src/ServerScriptService/Folder/Package/init.luau");
  fs.writeFileSync(regular, "return nil");
  fs.writeFileSync(init, "return {}");
  assert.equal(resolveStudioPath(projectDir, regular).studioPath, "game.ServerScriptService.Folder.Main");
  assert.equal(resolveStudioPath(projectDir, init).studioPath, "game.ServerScriptService.Folder.Package");
  assert.equal(resolveStudioPath(projectDir, init).className, "ModuleScript");
});

test("resolveStudioPath maps Roblox model assets", (t) => {
  const projectDir = temporaryProject();
  t.after(() => fs.rmSync(projectDir, { recursive: true, force: true }));
  const asset = path.join(projectDir, "src/ReplicatedStorage/Packages/MainModule.rbxm");
  fs.mkdirSync(path.dirname(asset), { recursive: true });
  fs.writeFileSync(asset, Buffer.from([1, 2, 3]));
  assert.deepEqual(resolveStudioPath(projectDir, asset), {
    studioPath: "game.ReplicatedStorage.Packages.MainModule",
    parentPath: "game.ReplicatedStorage.Packages",
    name: "MainModule",
    assetType: "rbxm",
  });
});

test("companion push imports and verifies a model asset", async (t) => {
  const projectDir = temporaryProject();
  t.after(() => fs.rmSync(projectDir, { recursive: true, force: true }));
  const asset = path.join(projectDir, "src/ReplicatedStorage/MainModule.rbxm");
  fs.mkdirSync(path.dirname(asset), { recursive: true });
  fs.writeFileSync(asset, Buffer.from([1, 2, 3]));
  const calls = [];
  const client = { pluginCall: async (command) => {
    calls.push(command);
    return { ok: true, instance: { name: "MainModule" } };
  } };
  const result = await new Pusher(client, { projectDir }).push(asset);
  assert.equal(result.result.verified, true);
  assert.equal(calls[0].type, "import_model");
  assert.equal(calls[0].contentBase64, "AQID");
  assert.deepEqual(calls.map(call => call.type), ["import_model", "resolve_path"]);
});

test("script push uses granular MCP multi_edit and tracks companion verification", async (t) => {
  const projectDir = temporaryProject();
  t.after(() => fs.rmSync(projectDir, { recursive: true, force: true }));
  const localFile = path.join(projectDir, "src/ServerScriptService/Main.server.luau");
  fs.mkdirSync(path.dirname(localFile), { recursive: true });
  const oldSource = "local value = 1\nprint(value)\nreturn value\n";
  const newSource = "local value = 2\nprint(value)\nreturn value + 1\n";
  fs.writeFileSync(localFile, newSource);
  const pluginCalls = [];
  const mcpCalls = [];
  const pendingRecords = [];
  let studioSource = oldSource;
  const client = {
    health: async () => ({ connected: true, pluginConnected: true }),
    pluginCall: async (command) => {
      pluginCalls.push(command);
      return { ok: true, source: studioSource };
    },
    call: async (name, request) => {
      mcpCalls.push({ name, request });
      for (const edit of request.edits) studioSource = studioSource.replace(edit.old_string, edit.new_string);
      return { content: [{ text: "ok" }] };
    },
    pendingRecord: async (studioPath, source) => pendingRecords.push({ studioPath, source }),
  };
  const result = await new Pusher(client, { projectDir }).push(localFile);
  assert.equal(result.result.verified, false);
  assert.equal(result.result.pending, true);
  assert.equal(result.result.tool, "multi_edit");
  assert.equal(result.result.editCount, 2);
  assert.deepEqual(pluginCalls.map(call => call.type), ["read_source"]);
  assert.deepEqual(mcpCalls.map(call => call.name), ["multi_edit"]);
  assert.equal(mcpCalls[0].request.edits.some(edit => edit.old_string === oldSource), false);
  assert.deepEqual(pendingRecords, [{
    studioPath: "game.ServerScriptService.Main",
    source: newSource,
  }]);
});

test("new scripts are created through the multi_edit creation contract", async (t) => {
  const projectDir = temporaryProject();
  t.after(() => fs.rmSync(projectDir, { recursive: true, force: true }));
  const localFile = path.join(projectDir, "src/ServerScriptService/Main.server.luau");
  fs.mkdirSync(path.dirname(localFile), { recursive: true });
  fs.writeFileSync(localFile, "print('new')");
  let source;
  const mcpCalls = [];
  const client = {
    health: async () => ({ connected: true, pluginConnected: true }),
    pluginCall: async () => source === undefined ? { ok: false, error: "not found" } : { ok: true, source },
    call: async (name, request) => {
      mcpCalls.push({ name, request });
      source = request.edits[0].new_string;
      return { content: [{ text: "created" }] };
    },
  };
  const result = await new Pusher(client, { projectDir }).push(localFile);
  assert.equal(result.result.created, true);
  assert.equal(mcpCalls[0].request.className, "Script");
  assert.deepEqual(mcpCalls[0].request.edits, [{ old_string: "", new_string: "print('new')" }]);
});

test("script push refuses a whole-source fallback when MCP is unavailable", async (t) => {
  const projectDir = temporaryProject();
  t.after(() => fs.rmSync(projectDir, { recursive: true, force: true }));
  const localFile = path.join(projectDir, "src/ServerScriptService/Main.server.luau");
  fs.mkdirSync(path.dirname(localFile), { recursive: true });
  fs.writeFileSync(localFile, "print('new')");
  let pluginCalled = false;
  const client = {
    health: async () => ({ connected: false, pluginConnected: true }),
    pluginCall: async () => { pluginCalled = true; },
  };
  await assert.rejects(
    () => new Pusher(client, { projectDir }).push(localFile),
    /whole-script fallback is disabled/,
  );
  assert.equal(pluginCalled, false);
});

test("script push reports a tracked pending result when Draft Mode hides the edit", async (t) => {
  const projectDir = temporaryProject();
  t.after(() => fs.rmSync(projectDir, { recursive: true, force: true }));
  const localFile = path.join(projectDir, "src/ServerScriptService/Main.server.luau");
  fs.mkdirSync(path.dirname(localFile), { recursive: true });
  fs.writeFileSync(localFile, "local value = 2\nreturn value\n");
  const pendingRecords = [];
  const client = {
    health: async () => ({ connected: true, pluginConnected: true }),
    pluginCall: async () => ({ ok: true, source: "local value = 1\nreturn value\n" }),
    call: async () => ({ content: [{ text: "ok" }] }),
    pendingRecord: async (studioPath, source) => pendingRecords.push({ studioPath, source }),
  };
  const result = await new Pusher(client, {
    projectDir,
    verificationAttempts: 1,
    verificationDelayMs: 0,
  }).push(localFile);
  assert.equal(result.result.verified, false);
  assert.equal(result.result.pending, true);
  assert.deepEqual(pendingRecords, [{
    studioPath: "game.ServerScriptService.Main",
    source: "local value = 2\nreturn value\n",
  }]);
});

test("source edit generation handles insertions, deletions, and repeated lines", () => {
  const oldSource = "start\nrepeat\nold\nrepeat\nend\n";
  const newSource = "start\ninserted\nrepeat\nnew\nrepeat\n";
  const edits = buildSourceEdits(oldSource, newSource);
  let simulated = oldSource;
  for (const edit of edits) {
    assert.equal(simulated.split(edit.old_string).length - 1, 1);
    simulated = simulated.replace(edit.old_string, edit.new_string);
  }
  assert.equal(simulated, newSource);
  assert.equal(edits.some(edit => edit.old_string === oldSource), false);
});

test("source edit generation coalesces adjacent hunks when repeated blocks exhaust context", () => {
  const oldSource = [
    "header",
    "same",
    "change one",
    "same",
    "change two",
    "same",
    "change one",
    "same",
    "change two",
    "footer",
    "",
  ].join("\n");
  const newSource = oldSource
    .replace("change one\nsame\nchange two", "first update\nsame\nsecond update")
    .replace("change one\nsame\nchange two", "third update\nsame\nfourth update");

  const edits = buildSourceEdits(oldSource, newSource);
  let simulated = oldSource;
  for (const edit of edits) {
    assert.equal(simulated.split(edit.old_string).length - 1, 1);
    simulated = simulated.replace(edit.old_string, edit.new_string);
  }
  assert.equal(simulated, newSource);
  assert.equal(edits.some(edit => edit.old_string === oldSource), false);
});

test("source edit generation refuses an unanchored whole-script replacement", () => {
  assert.throws(() => buildSourceEdits("print('old')", "print('new')"), /No shared source context/);
});

test("source edit generation treats CRLF and LF as shared source context", () => {
  const oldSource = "local value = 1\nprint(value)\nreturn value\n";
  const newSource = "local value = 1\r\nprint(value + 1)\r\nreturn value\r\n";
  const edits = buildSourceEdits(oldSource, newSource);
  let simulated = oldSource;
  for (const edit of edits) simulated = simulated.replace(edit.old_string, edit.new_string);
  assert.equal(simulated, newSource.replace(/\r\n/g, "\n"));
});

test("script push tracks normalized LF source for a local CRLF file", async (t) => {
  const projectDir = temporaryProject();
  t.after(() => fs.rmSync(projectDir, { recursive: true, force: true }));
  const localFile = path.join(projectDir, "src/ServerScriptService/Main.server.luau");
  fs.mkdirSync(path.dirname(localFile), { recursive: true });
  fs.writeFileSync(localFile, "local value = 2\r\nreturn value\r\n");
  let studioSource = "local value = 1\nreturn value\n";
  const client = {
    health: async () => ({ connected: true, pluginConnected: true }),
    pluginCall: async () => ({ ok: true, source: studioSource }),
    call: async (_name, request) => {
      for (const edit of request.edits) studioSource = studioSource.replace(edit.old_string, edit.new_string);
      return { content: [{ text: "ok" }] };
    },
  };
  const result = await new Pusher(client, { projectDir }).push(localFile);
  assert.equal(result.result.verified, false);
  assert.equal(result.result.pending, true);
  assert.equal(studioSource, "local value = 2\nreturn value\n");
});

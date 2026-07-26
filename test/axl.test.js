const assert = require("node:assert/strict");
const test = require("node:test");

const {
  AxlError,
  encodeAxlError,
  executePluginAxl,
  parseAxl,
} = require("../lib/axl");

test("AXL parses core read forms into typed nodes", () => {
  assert.deepEqual(parseAxl("read game.ServerScriptService.MatchManager lines 84..143"), {
    type: "read",
    target: {
      kind: "path",
      path: "game.ServerScriptService.MatchManager",
      revision: null,
      namespaceVersion: null,
      raw: "game.ServerScriptService.MatchManager",
    },
    detail: "lines",
    range: { start: 84, end: 143 },
  });

  assert.equal(parseAxl("read #41 source").target.kind, "symbol");
  assert.equal(parseAxl("read #41@17 ^9 source").target.revision, 17);
});

test("AXL parses quoted tasks, budgets, and execution modes", () => {
  assert.deepEqual(parseAxl('context "round ends twice" budget=700'), {
    type: "context",
    task: "round ends twice",
    budget: 700,
  });
  assert.deepEqual(parseAxl('execute "return true" mode=Client'), {
    type: "execute",
    code: "return true",
    mode: "Client",
  });
  assert.deepEqual(parseAxl("execute <<LUAU mode=Edit\nprint('ok')\nLUAU"), {
    type: "execute",
    code: "print('ok')",
    mode: "Edit",
  });
});

test("AXL parses exact revision-checked patches", () => {
  const ast = parseAxl(`patch game.ServerScriptService.Main@42
old <<OLD
local speed = 10
OLD
new <<NEW
local speed = 20
NEW`);
  assert.equal(ast.type, "patch");
  assert.equal(ast.target.revision, 42);
  assert.equal(ast.oldText, "local speed = 10");
  assert.equal(ast.newText, "local speed = 20");
});

test("AXL rejects invalid syntax before transport", () => {
  assert.throws(() => parseAxl('find "round" surprise=yes'), /Unknown option/);
  assert.throws(() => parseAxl("patch game.ServerScriptService.Main"), /requires target@revision/);
  assert.throws(
    () => parseAxl("read game.ServerScriptService.Main lines 10..2"),
    (error) => error instanceof AxlError && error.code === "VALUE",
  );
});

test("production AXL delegates the original compact text to the Studio plugin", async () => {
  const calls = [];
  const source = 'find "EndRound" budget=500';
  const client = {
    pluginCall: async (command) => {
      calls.push(command);
      return { ok: true, result: { ok: true, response: "OK FIND n=2 t=12\nA:1\nB:2" } };
    },
  };

  assert.equal(await executePluginAxl(source, client), "OK FIND n=2 t=12\nA:1\nB:2");
  assert.deepEqual(calls, [{ type: "axl", source }]);
});

test("production AXL requires a compact plugin response", async () => {
  await assert.rejects(
    executePluginAxl("state", { pluginCall: async () => ({ ok: true }) }),
    (error) => error instanceof AxlError && error.code === "RESPONSE",
  );
});

test("AXL errors retain compact transport codes", () => {
  assert.match(encodeAxlError(new Error("Roblox Studio not connected")), /^ERR NOSTUDIO /);
  assert.equal(
    encodeAxlError(new AxlError("STALE", "Target revision changed", { expected: 1, current: 2 })),
    "ERR STALE expected=1 current=2 Target revision changed",
  );
});

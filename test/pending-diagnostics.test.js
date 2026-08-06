"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { createServer, pendingPushes, pluginServer } = require("../server");
const { MCPClient } = require("../client");

test("production server /pending/verify returns actionable diagnostic when Studio companion is disconnected without corrupting pending state", async (t) => {
  pendingPushes.clear();
  pendingPushes.recordPush("game.ServerScriptService.Main", "local x = 1\n");
  const initialEntry = pendingPushes.get("game.ServerScriptService.Main");
  assert.equal(initialEntry.status, "pending");

  assert.equal(pluginServer.isConnected(), false);

  const server = await createServer(null, 0);
  const address = server.address();
  const port = typeof address === "object" ? address.port : address;
  t.after(() => {
    server.close();
    pendingPushes.clear();
  });

  // 1. Direct HTTP test against production server route handler
  const res = await fetch(`http://127.0.0.1:${port}/pending/verify`, { method: "POST" });
  const data = await res.json();

  assert.equal(data.ok, false);
  assert.equal(data.reason, "companion_disconnected");
  assert.equal(data.connected, false);
  assert.ok(data.error.includes("Studio companion is disconnected"));

  // Assert pending entry status was NOT mutated to "error"
  const entryAfter = pendingPushes.get("game.ServerScriptService.Main");
  assert.equal(entryAfter.status, "pending");
  assert.equal(entryAfter.error, null);
});

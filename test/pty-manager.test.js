"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { PtyManager } = require("../app/Abraxius.Linux/pty-manager");

test("PtyManager creates, writes, resizes, and closes PTY sessions", async () => {
  const ptyManager = new PtyManager();

  const session = ptyManager.createSession({
    name: "Test Shell",
    command: "/bin/bash",
    args: [],
  });

  assert.ok(session.id, "Session should have an ID");
  assert.equal(session.name, "Test Shell");
  assert.equal(session.state, "running");

  const list = ptyManager.listSessions();
  assert.equal(list.length, 1);
  assert.equal(list[0].id, session.id);

  ptyManager.writeInput(session.id, "echo HELLO_PTY\n");
  const resizeRes = ptyManager.resize(session.id, 100, 30);
  assert.equal(resizeRes.resized, true);

  await new Promise((r) => setTimeout(r, 100));

  const closeRes = ptyManager.closeSession(session.id);
  assert.equal(closeRes.closed, true);
  assert.equal(ptyManager.listSessions().length, 0);
});

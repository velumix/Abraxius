"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { PtyManager } = require("../app/Abraxius.Linux/pty-manager");

test("PtyManager creates, manages, and logs activity for real PTY processes", async () => {
  const manager = new PtyManager();

  const session = manager.createSession({
    name: "Bash Test",
    command: "/bin/bash",
    args: [],
  });

  assert.ok(session.id);
  assert.equal(session.name, "Bash Test");
  assert.equal(session.state, "running");

  const sessions = manager.listSessions();
  assert.equal(sessions.length, 1);
  assert.equal(sessions[0].id, session.id);

  manager.writeInput(session.id, "echo PTY_WORKSPACE_OK\n");
  const resizeResult = manager.resize(session.id, 120, 40);
  assert.equal(resizeResult.resized, true);

  await new Promise((resolve) => setTimeout(resolve, 100));

  const closeResult = manager.closeSession(session.id);
  assert.equal(closeResult.closed, true);
  assert.equal(manager.listSessions().length, 0);
});

test("preload.js and tauri-bridge.js expose pty methods contract", () => {
  const preloadPath = path.join(__dirname, "../app/Abraxius.Linux/preload.js");
  const bridgePath = path.join(__dirname, "../app/Abraxius.Linux/renderer/tauri-bridge.js");

  const preloadContent = fs.readFileSync(preloadPath, "utf8");
  const bridgeContent = fs.readFileSync(bridgePath, "utf8");

  const requiredPtyMethods = ["list", "create", "write", "resize", "stop", "restart", "close", "getBuffer", "getHistory", "onEvent", "onActivity"];

  for (const method of requiredPtyMethods) {
    assert.ok(preloadContent.includes(`${method}:`), `preload.js must expose pty.${method}`);
    assert.ok(bridgeContent.includes(`${method}:`), `tauri-bridge.js must expose pty.${method}`);
  }
});

test("index.html contains Workspace Shell, Tabbed PTY Manager, Command Palette, and Context Menu", () => {
  const htmlPath = path.join(__dirname, "../app/Abraxius.Linux/renderer/index.html");
  const html = fs.readFileSync(htmlPath, "utf8");

  assert.ok(html.includes('id="pty-tab-bar"'), "PTY tab bar element");
  assert.ok(html.includes('id="pty-new-tab-btn"'), "New PTY tab button");
  assert.ok(html.includes('id="workspace-panes-wrapper"'), "Multi-pane resizable grid wrapper");
  assert.ok(html.includes('id="pane-resizer"'), "Pane resizer handle");
  assert.ok(html.includes('id="open-command-palette"'), "Command palette button");
  assert.ok(html.includes('id="command-palette-modal"'), "Command palette modal");
  assert.ok(html.includes('id="terminal-context-menu"'), "Terminal context menu");
  assert.ok(html.includes('id="approval-queue-bar"'), "Approval queue bar");
  assert.ok(html.includes('id="activity-timeline-drawer"'), "Activity timeline drawer");
  assert.ok(html.includes('id="mode-chip-llm"'), "LLM Prompt composer mode");
  assert.ok(html.includes('id="mode-chip-shell"'), "Shell Command composer mode");
});

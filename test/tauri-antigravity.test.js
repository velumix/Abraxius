"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const { AgySession } = require("../app/Abraxius.Linux/antigravity/src/agy-session");

test("tauri-bridge.js configures real-time event listening for Antigravity", () => {
  const bridgePath = path.join(__dirname, "../app/Abraxius.Linux/renderer/tauri-bridge.js");
  const content = fs.readFileSync(bridgePath, "utf8");

  assert.ok(
    content.includes('onEvent: (callback) => events("antigravity-event", callback)'),
    "tauri-bridge.js must use real-time events for antigravity.onEvent rather than polling replayEvents",
  );
  assert.equal(
    content.includes('onEvent: (callback) => replayEvents("antigravity-event", callback)'),
    false,
    "tauri-bridge.js must not poll with replayEvents for antigravity.onEvent",
  );
});

test("AgySession writeInput preserves keyboard input during active prompt execution and connecting states", () => {
  const session = new AgySession({ autoReconnect: false });

  // Stopped state should reject
  assert.deepEqual(session.writeInput("y\r"), { written: false, reason: "session_stopped" });

  // Connecting state (e.g. trust prompt) should allow keyboard input
  session.state = "connecting";
  const writtenConnecting = [];
  session.child = { stdin: { writable: true, write: (val) => writtenConnecting.push(val) } };
  assert.deepEqual(session.writeInput("y\r"), { written: true, bytes: 2 });
  assert.deepEqual(writtenConnecting, ["y\r"]);

  // Busy active state (e.g. tool permission prompt / interactive confirmation during prompt execution)
  session.state = "busy";
  session.active = { envelope: { id: "test-active" } };
  const writtenBusy = [];
  session.child = { stdin: { writable: true, write: (val) => writtenBusy.push(val) } };
  assert.deepEqual(session.writeInput("y\r"), { written: true, bytes: 2 });
  assert.deepEqual(writtenBusy, ["y\r"]);

  // Queued state should also preserve interactive input
  session.state = "ready";
  session.active = null;
  session.queue.push({ envelope: { id: "queued-1" } });
  const writtenQueued = [];
  session.child = { stdin: { writable: true, write: (val) => writtenQueued.push(val) } };
  assert.deepEqual(session.writeInput("\x03"), { written: true, bytes: 1 });
  assert.deepEqual(writtenQueued, ["\x03"]);
});

test("styles.css declares Google Sans Code font family for regular, medium, semibold, and bold weights", () => {
  const cssPath = path.join(__dirname, "../app/Abraxius.Linux/renderer/styles.css");
  const css = fs.readFileSync(cssPath, "utf8");

  assert.ok(css.includes('font-family: "Google Sans Code"'), "font-family declaration");
  assert.ok(css.includes('src: url("fonts/GoogleSansCode-Regular.ttf")'), "Regular font weight 400");
  assert.ok(css.includes('src: url("fonts/GoogleSansCode-Medium.ttf")'), "Medium font weight 500");
  assert.ok(css.includes('src: url("fonts/GoogleSansCode-SemiBold.ttf")'), "SemiBold font weight 600");
  assert.ok(css.includes('src: url("fonts/GoogleSansCode-Bold.ttf")'), "Bold font weight 700");
});

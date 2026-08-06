"use strict";

const assert = require("node:assert/strict");
const { EventEmitter } = require("node:events");
const { PassThrough, Writable } = require("node:stream");
const test = require("node:test");
const { AgySession, resolveAgyCommand, terminalQueryResponse } = require("../src/agy-session");

function createFakeProcess() {
  const child = new EventEmitter();
  child.pid = 424242;
  child.stdout = new PassThrough();
  child.stderr = new PassThrough();
  child.stdin = new Writable({
    write(chunk, _encoding, callback) {
      const prompt = chunk.toString();
      const id = prompt.match(/"BEGIN_", "([^"]+)"/)?.[1];
      if (id) {
        process.nextTick(() => {
          child.stdout.write(`<ABRAXIUS_BEGIN_${id}>\r\nBridge response\r\n<ABRAXIUS_DONE_${id}>\r\n`);
        });
      }
      callback();
    },
  });
  process.nextTick(() => child.stdout.write("Antigravity CLI 1.1.10\r\n? for shortcuts\r\n"));
  return child;
}

test("terminalQueryResponse answers capability checks from interactive TUIs", () => {
  const response = terminalQueryResponse(
    "\x1B[?2026$p\x1B[?2027$p\x1B[?u\x1B[6n\x1B[5n\x1B[>c\x1B[c",
  );

  assert.equal(
    response,
    "\x1B[?2026;2$y\x1B[?2027;2$y\x1B[?0u\x1B[1;1R\x1B[0n\x1B[>0;0;0c\x1B[?1;2c",
  );
});

test("resolveAgyCommand finds binary in system path or standard directories", () => {
  const resolved = resolveAgyCommand();
  assert.equal(typeof resolved, "string");
  assert.ok(resolved.length > 0);
});

test("AgySession waits for readiness and resolves a framed response", async () => {
  let child;
  const session = new AgySession({
    autoReconnect: false,
    spawnProcess: () => {
      child = createFakeProcess();
      return child;
    },
  });

  const states = [];
  session.on("state", ({ state }) => states.push(state));
  const result = await session.send("Say hello");

  assert.equal(result.text, "Bridge response");
  assert.equal(session.status().ready, true);
  assert.deepEqual(states.slice(0, 3), ["connecting", "ready", "busy"]);

  child.emit("exit", 0, null);
  assert.equal(session.status().state, "stopped");
});

test("writeInput rejects input when stopped but accepts trust-prompt input while connecting", () => {
  const session = new AgySession({ autoReconnect: false });
  assert.deepEqual(session.writeInput("hello"), { written: false, reason: "session_stopped" });

  session.state = "connecting";
  const written = [];
  session.child = { stdin: { writable: true, write: (value) => written.push(value) } };
  assert.deepEqual(session.writeInput("hello"), { written: true, bytes: 5 });
  assert.deepEqual(written, ["hello"]);
});

test("writeInput enforces input type, length, and limit checks", () => {
  const session = new AgySession({ autoReconnect: false });
  assert.deepEqual(session.writeInput(123), { written: false, reason: "invalid_input" });
  assert.deepEqual(session.writeInput(""), { written: false, reason: "empty_input" });
  assert.deepEqual(session.writeInput("x".repeat(9000)), { written: false, reason: "exceeds_max_length" });
});

test("writeInput accepts data for ready idle session and preserves exact terminal bytes", async () => {
  let child;
  const writtenChunks = [];

  const session = new AgySession({
    autoReconnect: false,
    spawnProcess: () => {
      child = createFakeProcess();
      const origWrite = child.stdin.write.bind(child.stdin);
      child.stdin.write = (chunk, encoding, callback) => {
        writtenChunks.push(chunk.toString());
        return origWrite(chunk, encoding, callback);
      };
      return child;
    },
  });

  await session.start();
  assert.equal(session.status().ready, true);

  // Test normal text & control bytes
  const input1 = "ls -la\r";
  const input2 = "\x1B[A\x7F\x03";
  const input3 = "\x1B[200~pasted code\x1B[201~";

  const res1 = session.writeInput(input1);
  assert.deepEqual(res1, { written: true, bytes: Buffer.byteLength(input1) });

  const res2 = session.writeInput(input2);
  assert.deepEqual(res2, { written: true, bytes: Buffer.byteLength(input2) });

  const res3 = session.writeInput(input3);
  assert.deepEqual(res3, { written: true, bytes: Buffer.byteLength(input3) });

  assert.ok(writtenChunks.includes(input1));
  assert.ok(writtenChunks.includes(input2));
  assert.ok(writtenChunks.includes(input3));

  // Test interactive keyboard input preservation during active prompt / queued states (trust prompts, CLI confirmations)
  session.active = { envelope: { id: "test-active" } };
  assert.deepEqual(session.writeInput("interactive y\r"), { written: true, bytes: 14 });

  session.active = null;
  session.queue.push({});
  assert.deepEqual(session.writeInput("interactive y\r"), { written: true, bytes: 14 });

  session.queue = [];
  child.emit("exit", 0, null);
});

test("AgySession calculates bounded exponential reconnect delay with jitter", () => {
  const session = new AgySession({
    autoReconnect: true,
    reconnectPolicy: {
      initialDelayMs: 1000,
      maxDelayMs: 5000,
      backoffFactor: 2,
      maxAttempts: 5,
      jitter: (delay, attempt) => delay + attempt,
    },
  });

  assert.equal(session.calculateReconnectDelay(1), 1001); // 1000 + 1
  assert.equal(session.calculateReconnectDelay(2), 2002); // 2000 + 2
  assert.equal(session.calculateReconnectDelay(3), 4003); // 4000 + 3
  assert.equal(session.calculateReconnectDelay(4), 5004); // min(5000, 8000) + 4
});

test("AgySession emits attempt metadata on reconnect and stops when maxAttempts is reached", async () => {
  let timerCb = null;
  const timerEvents = [];

  const session = new AgySession({
    autoReconnect: true,
    reconnectPolicy: {
      initialDelayMs: 100,
      maxDelayMs: 1000,
      backoffFactor: 2,
      maxAttempts: 2,
    },
    setTimeout: (cb, delay) => {
      timerCb = cb;
      timerEvents.push(delay);
      return { unref: () => {} };
    },
    clearTimeout: () => {
      timerCb = null;
    },
    spawnProcess: () => createFakeProcess(),
  });

  const reconnectEvents = [];
  session.on("reconnecting", (data) => reconnectEvents.push(data));

  const faults = [];
  session.on("fault", (f) => faults.push(f));

  // Start initial session
  void session.start().catch(() => {});
  const child1 = session.child;
  child1.emit("exit", 1, null);

  assert.equal(reconnectEvents.length, 1);
  assert.equal(reconnectEvents[0].attempt, 1);
  assert.equal(reconnectEvents[0].delay, 100);
  assert.equal(reconnectEvents[0].maxAttempts, 2);
  assert.equal(session.status().reconnectAttempt, 1);

  // Trigger timer callback for 2nd reconnect attempt
  assert.equal(typeof timerCb, "function");
  const currentCb1 = timerCb;
  timerCb = null;
  currentCb1();

  const child2 = session.child;
  child2.emit("exit", 1, null);

  assert.equal(reconnectEvents.length, 2);
  assert.equal(reconnectEvents[1].attempt, 2);
  assert.equal(reconnectEvents[1].delay, 200);

  // Trigger timer callback for 3rd reconnect attempt -> maxAttempts (2) hit on exit
  assert.equal(typeof timerCb, "function");
  const currentCb2 = timerCb;
  timerCb = null;
  currentCb2();

  const child3 = session.child;
  child3.emit("exit", 1, null);

  assert.equal(faults.length, 1);
  assert.equal(faults[0].phase, "reconnect_limit");
  assert.equal(session.status().state, "stopped");
});

test("AgySession intentional stop cancels reconnect timer and resets attempt counter", async () => {
  let cleared = false;
  const session = new AgySession({
    autoReconnect: true,
    setTimeout: () => ({ unref: () => {} }),
    clearTimeout: () => { cleared = true; },
    spawnProcess: () => createFakeProcess(),
  });

  void session.start().catch(() => {});
  session.child.emit("exit", 1, null);

  assert.equal(session.status().state, "reconnecting");
  assert.equal(session.status().reconnectAttempt, 1);

  await session.stop();

  assert.equal(cleared, true);
  assert.equal(session.status().state, "stopped");
  assert.equal(session.status().reconnectAttempt, 0);
  assert.equal(session.status().reconnectDelay, 0);
});


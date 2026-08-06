"use strict";

const assert = require("node:assert/strict");
const { EventEmitter } = require("node:events");
const test = require("node:test");
const { createBridgeServer } = require("../src/bridge-server");

class FakeSession extends EventEmitter {
  status() { return { state: "ready", ready: true, busy: false, queued: 0 }; }
  start() { return Promise.resolve(this.status()); }
  send(prompt, options) {
    this.emit("request", { id: options.id, prompt });
    return Promise.resolve({ id: options.id, text: "READY", durationMs: 1 });
  }
  cancel() { return false; }
  writeInput(data) {
    if (typeof data !== "string") return { written: false, reason: "invalid_input" };
    return { written: true, bytes: Buffer.byteLength(data) };
  }
}

test("job API acknowledges immediately and retains the result", async () => {
  const bridge = createBridgeServer({
    session: new FakeSession(),
    host: "127.0.0.1",
    port: 0,
    token: "test-token",
  });
  await bridge.listen();
  const port = bridge.server.address().port;
  const headers = { authorization: "Bearer test-token", "content-type": "application/json" };

  try {
    const submitted = await fetch(`http://127.0.0.1:${port}/v1/jobs`, {
      method: "POST",
      headers,
      body: JSON.stringify({ prompt: "Reply READY" }),
    });
    assert.equal(submitted.status, 202);
    const { job } = await submitted.json();
    assert.match(job.id, /^[0-9a-f-]{36}$/);

    await new Promise((resolve) => setImmediate(resolve));
    const response = await fetch(`http://127.0.0.1:${port}/v1/jobs/${job.id}`, { headers });
    assert.equal(response.status, 200);
    const completed = (await response.json()).job;
    assert.equal(completed.status, "completed");
    assert.equal(completed.result.text, "READY");
  } finally {
    await bridge.close();
  }
});

test("prompt stream API streams responses over SSE", async () => {
  const session = new FakeSession();
  const bridge = createBridgeServer({
    session,
    host: "127.0.0.1",
    port: 0,
    token: "test-token",
  });
  await bridge.listen();
  const headers = { authorization: "Bearer test-token", "content-type": "application/json" };

  try {
    const res = await fetch(`http://127.0.0.1:${bridge.port}/v1/prompt/stream`, {
      method: "POST",
      headers,
      body: JSON.stringify({ prompt: "Say hello" }),
    });
    assert.equal(res.status, 200);
    assert.match(res.headers.get("content-type"), /text\/event-stream/);
    const text = await res.text();
    assert.match(text, /event: response/);
    assert.match(text, /READY/);
  } finally {
    await bridge.close();
  }
});

test("bridge server falls back to next port if initial port is occupied", async () => {
  const session = new FakeSession();
  const b1 = createBridgeServer({ session, host: "127.0.0.1", port: 0, token: "tok" });
  await b1.listen();
  const occupiedPort = b1.port;

  const b2 = createBridgeServer({
    session,
    host: "127.0.0.1",
    port: occupiedPort,
    fallbackPorts: [occupiedPort, occupiedPort + 1, occupiedPort + 2],
    token: "tok",
  });

  try {
    await b2.listen();
    assert.notEqual(b2.port, occupiedPort);
    assert.ok([occupiedPort + 1, occupiedPort + 2].includes(b2.port));
  } finally {

    await b1.close();
    await b2.close();
  }
});

test("input API forwards raw input data to session", async () => {
  const session = new FakeSession();
  const bridge = createBridgeServer({ session, host: "127.0.0.1", port: 0, token: "tok" });
  await bridge.listen();
  const headers = { authorization: "Bearer tok", "content-type": "application/json" };

  try {
    const res = await fetch(`http://127.0.0.1:${bridge.port}/v1/session/input`, {
      method: "POST",
      headers,
      body: JSON.stringify({ data: "ls -la\r" }),
    });
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.ok, true);
    assert.equal(body.result.written, true);
  } finally {
    await bridge.close();
  }
});

test("bridge server enforces authorization on protected endpoints", async () => {
  const session = new FakeSession();
  const bridge = createBridgeServer({ session, host: "127.0.0.1", port: 0, token: "secret-token" });
  await bridge.listen();

  try {
    const health = await fetch(`http://127.0.0.1:${bridge.port}/health`);
    assert.equal(health.status, 200);

    const noAuth = await fetch(`http://127.0.0.1:${bridge.port}/v1/session/start`, { method: "POST" });
    assert.equal(noAuth.status, 401);
    assert.equal((await noAuth.json()).error, "Unauthorized");

    const badAuth = await fetch(`http://127.0.0.1:${bridge.port}/v1/session/start`, {
      method: "POST",
      headers: { authorization: "Bearer invalid-token" },
    });
    assert.equal(badAuth.status, 401);

    const queryAuth = await fetch(`http://127.0.0.1:${bridge.port}/v1/session/start?token=secret-token`, {
      method: "POST",
    });
    assert.equal(queryAuth.status, 200);
    assert.equal((await queryAuth.json()).ok, true);
  } finally {
    await bridge.close();
  }
});



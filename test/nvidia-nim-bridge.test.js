"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const http = require("node:http");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

const {
  createNimBridgeServer,
  getNimBridgeInfo,
  saveNimBridgeInfo,
  timingSafeEqual,
} = require("../lib/nvidia-nim-bridge");

test("timingSafeEqual correctly compares tokens", () => {
  assert.equal(timingSafeEqual("secret123", "secret123"), true);
  assert.equal(timingSafeEqual("secret123", "wrongtoken"), false);
  assert.equal(timingSafeEqual("", "secret123"), false);
  assert.equal(timingSafeEqual(null, "secret123"), false);
});

test("saveNimBridgeInfo and getNimBridgeInfo persist token with mode 0600", () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "nim-bridge-test-"));
  try {
    saveNimBridgeInfo(tmpDir, { port: 14500, token: "test-token-123" });
    const info = getNimBridgeInfo(tmpDir);
    assert.deepEqual(info, { port: 14500, token: "test-token-123" });

    const tokenFile = path.join(tmpDir, "linux", "nvidia-nim-token");
    const jsonFile = path.join(tmpDir, "linux", "nvidia-nim-bridge.json");
    assert.equal(fs.existsSync(tokenFile), true);
    assert.equal(fs.existsSync(jsonFile), true);

    const tokenStat = fs.statSync(tokenFile);
    const jsonStat = fs.statSync(jsonFile);
    assert.equal(tokenStat.mode & 0o777, 0o600);
    assert.equal(jsonStat.mode & 0o777, 0o600);
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test("NVIDIA NIM bridge authentication rejects invalid tokens and permits valid tokens", async () => {
  const bridge = createNimBridgeServer({
    getApiKey: () => "valid-key-123",
    token: "auth-secret-abc",
    port: 0,
    clientFactory: () => ({
      streamChat: async ({ onChunk }) => {
        onChunk("hello");
        return { reasoning: "", fullText: "hello" };
      },
    }),
  });

  await bridge.listen();
  const port = bridge.port;

  try {
    // 1. GET /health works without auth
    const healthRes = await fetch(`http://127.0.0.1:${port}/health`);
    assert.equal(healthRes.status, 200);
    const healthData = await healthRes.json();
    assert.equal(healthData.ok, true);
    assert.equal(healthData.hasApiKey, true);

    // 2. POST without token returns 401
    const unauthRes = await fetch(`http://127.0.0.1:${port}/v1/nim/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ prompt: "hi" }),
    });
    assert.equal(unauthRes.status, 401);

    // 3. POST with wrong token returns 401
    const wrongAuthRes = await fetch(`http://127.0.0.1:${port}/v1/nim/chat`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer wrong-token",
      },
      body: JSON.stringify({ prompt: "hi" }),
    });
    assert.equal(wrongAuthRes.status, 401);

    // 4. POST with correct token succeeds
    const validRes = await fetch(`http://127.0.0.1:${port}/v1/nim/chat`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer auth-secret-abc",
      },
      body: JSON.stringify({ prompt: "hi" }),
    });
    assert.equal(validRes.status, 200);
    const text = await validRes.text();
    assert.match(text, /event: chunk/);
    assert.match(text, /hello/);
  } finally {
    await bridge.close();
  }
});

test("NVIDIA NIM bridge fans out events to UI callbacks and SSE stream without duplicate requests", async () => {
  let streamChatCalls = 0;
  const startEvents = [];
  const reasoningEvents = [];
  const chunkEvents = [];
  const endEvents = [];

  const bridge = createNimBridgeServer({
    getApiKey: () => "valid-key-123",
    token: "auth-secret-abc",
    port: 0,
    onChatStart: (evt) => startEvents.push(evt),
    onReasoning: (evt) => reasoningEvents.push(evt),
    onChunk: (evt) => chunkEvents.push(evt),
    onChatEnd: (evt) => endEvents.push(evt),
    clientFactory: () => ({
      streamChat: async ({ onReasoning, onChunk }) => {
        streamChatCalls++;
        onReasoning("Reasoning line 1\n");
        onChunk("Answer line 1\n");
        return { reasoning: "Reasoning line 1\n", fullText: "Answer line 1\n" };
      },
    }),
  });

  await bridge.listen();

  try {
    const res = await fetch(`http://127.0.0.1:${bridge.port}/v1/nim/chat`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${bridge.token}`,
      },
      body: JSON.stringify({ prompt: "Explain quantum computing", source: "cli" }),
    });

    assert.equal(res.status, 200);
    const bodyText = await res.text();

    // Verify streamChat was called EXACTLY ONCE
    assert.equal(streamChatCalls, 1);

    // Verify UI callbacks received events
    assert.equal(startEvents.length, 2);
    assert.equal(startEvents[0].status, "queued");
    assert.equal(startEvents[0].source, "cli");
    assert.equal(startEvents[0].prompt, "Explain quantum computing");
    assert.equal(startEvents[1].status, "running");

    assert.equal(reasoningEvents.length, 1);
    assert.equal(reasoningEvents[0].chunk, "Reasoning line 1\n");

    assert.equal(chunkEvents.length, 1);
    assert.equal(chunkEvents[0].chunk, "Answer line 1\n");

    assert.equal(endEvents.length, 1);
    assert.equal(endEvents[0].ok, true);
    assert.equal(endEvents[0].fullText, "Answer line 1\n");

    // Verify SSE stream contains reasoning, chunk, and done events
    assert.match(bodyText, /event: reasoning\ndata: \{"chunk":"Reasoning line 1\\n"\}/);
    assert.match(bodyText, /event: chunk\ndata: \{"chunk":"Answer line 1\\n"\}/);
    assert.match(bodyText, /event: done\ndata: \{"ok":true/);
  } finally {
    await bridge.close();
  }
});

test("NVIDIA NIM bridge queue policy executes single jobs sequentially", async () => {
  const executionOrder = [];

  const bridge = createNimBridgeServer({
    getApiKey: () => "valid-key-123",
    token: "auth-secret-abc",
    port: 0,
    clientFactory: () => ({
      streamChat: async ({ messages }) => {
        const prompt = messages[0].content;
        executionOrder.push(`start:${prompt}`);
        await new Promise((r) => setTimeout(r, 50));
        executionOrder.push(`end:${prompt}`);
        return { reasoning: "", fullText: `Done ${prompt}` };
      },
    }),
  });

  await bridge.listen();

  try {
    const job1 = fetch(`http://127.0.0.1:${bridge.port}/v1/nim/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${bridge.token}` },
      body: JSON.stringify({ prompt: "Job 1" }),
    });

    const job2 = fetch(`http://127.0.0.1:${bridge.port}/v1/nim/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${bridge.token}` },
      body: JSON.stringify({ prompt: "Job 2" }),
    });

    const [res1, res2] = await Promise.all([job1, job2]);
    await Promise.all([res1.text(), res2.text()]);

    assert.deepEqual(executionOrder, [
      "start:Job 1",
      "end:Job 1",
      "start:Job 2",
      "end:Job 2",
    ]);
  } finally {
    await bridge.close();
  }
});

test("NVIDIA NIM bridge cancellation aborts request and notifies UI", async () => {
  const endEvents = [];

  const bridge = createNimBridgeServer({
    getApiKey: () => "valid-key-123",
    token: "auth-secret-abc",
    port: 0,
    onChatEnd: (evt) => endEvents.push(evt),
    clientFactory: () => ({
      streamChat: async ({ signal }) => {
        return new Promise((resolve, reject) => {
          const timer = setTimeout(() => resolve({ reasoning: "", fullText: "Finished" }), 5000);
          signal.addEventListener("abort", () => {
            clearTimeout(timer);
            const err = new Error("Cancelled");
            err.name = "AbortError";
            reject(err);
          });
        });
      },
    }),
  });

  await bridge.listen();

  try {
    const { sessionId, promise } = bridge.submitJob({ prompt: "Long job", source: "ui" });
    assert.equal(bridge.cancelJob(sessionId), true);
    const result = await promise;
    assert.equal(result.ok, false);
    assert.equal(result.cancelled, true);

    assert.equal(endEvents.length, 1);
    assert.equal(endEvents[0].cancelled, true);
  } finally {
    await bridge.close();
  }
});

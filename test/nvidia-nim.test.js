"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  NvidiaNimClient,
  NvidiaNimError,
  DEFAULT_ENDPOINT,
  DEFAULT_MODEL,
} = require("../lib/nvidia-nim");

test("NVIDIA NIM streams reasoning and answer content with OpenAI-compatible payload", async () => {
  let request;
  const chunks = [];
  const reasoning = [];
  const body = {
    getReader() {
      let index = 0;
      const values = [
        Buffer.from('data: {"choices":[{"delta":{"reasoning_content":"Plan "}}]}\r\n'),
        Buffer.from(`data: {"choices":[{"delta":{"reasoning_content":"done. ","content":"Hello"}}]}\r\n\r\n`),
        Buffer.from('data: {"choices":[{"delta":{"content":"world"}}]}\n\ndata: [DONE]\n\n'),
      ];
      return {
        read: async () => (index < values.length ? { done: false, value: values[index++] } : { done: true }),
        cancel: async () => {},
      };
    },
  };
  const client = new NvidiaNimClient({
    apiKey: "runtime-key",
    fetch: async (url, options) => {
      request = { url, options };
      return { ok: true, body };
    },
  });

  const result = await client.streamChat({
    messages: [{ role: "user", content: "Hi" }],
    onReasoning: (chunk) => reasoning.push(chunk),
    onChunk: (chunk) => chunks.push(chunk),
  });

  assert.equal(request.url, `${DEFAULT_ENDPOINT}/chat/completions`);
  assert.equal(request.options.headers.Authorization, "Bearer runtime-key");
  const payload = JSON.parse(request.options.body);
  assert.equal(payload.model, DEFAULT_MODEL);
  assert.equal(payload.stream, true);
  assert.equal(payload.chat_template_kwargs.enable_thinking, true);
  assert.equal(payload.reasoning_budget, 16384);
  assert.deepEqual(reasoning, ["Plan ", "done. "]);
  assert.deepEqual(chunks, ["Hello", "world"]);
  assert.equal(result.reasoning, "Plan done. ");
  assert.equal(result.fullText, "Helloworld");
});

test("NVIDIA NIM rejects missing credentials without making a request", async () => {
  const client = new NvidiaNimClient({ fetch: async () => { throw new Error("must not fetch"); } });
  await assert.rejects(
    client.streamChat({ messages: [{ role: "user", content: "Hi" }] }),
    (error) => error instanceof NvidiaNimError && error.code === "NO_API_KEY",
  );
});

test("CLI exposes the NVIDIA NIM command with bridge delegation and safeStorage fallback", () => {
  const fs = require("node:fs");
  const source = fs.readFileSync(require("node:path").join(__dirname, "../cli.js"), "utf8");
  assert.match(source, /case "nim"/);
  assert.match(source, /NVIDIA_NIM_API_KEY/);
  assert.match(source, /tryRunNvidiaNimViaAppBridge/);
  assert.match(source, /runNvidiaNimWithSavedAppKey/);
  assert.doesNotMatch(source, /nvapi-[A-Za-z0-9_-]{20,}/);
});

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const {
  OpenRouterClient,
  OpenRouterError,
  parseRetryAfter,
  DEFAULT_MODEL,
  DEFAULT_ENDPOINT,
  loadOpenRouterSettings,
  saveOpenRouterSettings,
} = require("../lib/openrouter");

test("OpenRouter parseRetryAfter handles seconds and HTTP-date", () => {
  assert.equal(parseRetryAfter("5"), 5000);
  assert.equal(parseRetryAfter("0"), 0);
  assert.equal(parseRetryAfter(null), null);

  const futureDate = new Date(Date.now() + 10000).toUTCString();
  const parsedMs = parseRetryAfter(futureDate);
  assert.ok(parsedMs > 8000 && parsedMs <= 10000);
});

test("OpenRouter model discovery uses auth and parses models with free tagging", async () => {
  let request;
  const client = new OpenRouterClient({
    apiKey: "runtime-key",
    fetch: async (url, options) => {
      request = { url, options };
      return {
        ok: true,
        json: async () => ({
          data: [
            { id: DEFAULT_MODEL, name: "Ling 3.0 Flash", context_length: 262144, pricing: { prompt: "0", completion: "0" } },
            { id: "openai/gpt-4o", name: "GPT-4o", context_length: 128000, pricing: { prompt: "0.000005", completion: "0.000015" } },
          ],
        }),
      };
    },
  });
  const models = await client.listModels();
  assert.equal(request.url, `${DEFAULT_ENDPOINT}/models`);
  assert.equal(request.options.headers.Authorization, "Bearer runtime-key");
  assert.equal(models.length, 2);
  assert.equal(models[0].id, DEFAULT_MODEL);
  assert.equal(models[0].isFree, true);
  assert.equal(models[1].isFree, false);

  const freeModels = await client.listModels({ freeOnly: true });
  assert.equal(freeModels.length, 1);
  assert.equal(freeModels[0].id, DEFAULT_MODEL);
});

test("OpenRouter streaming chat emits SSE chunks and handles CRLF and split buffers", async () => {
  const chunks = [];
  const body = {
    getReader() {
      let index = 0;
      const values = [
        Buffer.from(': keepalive\r\ndata: {"choices":[{"delta":{"content":"Hello"}}]}\r\n'),
        Buffer.from('data: {"choices":[{"delta":{"content":" world"}}]}\r\n\r\ndata: invalid-json-frame\r\n'),
        Buffer.from("data: [DONE]\r\n\r\n"),
      ];
      return {
        read: async () => (index < values.length ? { done: false, value: values[index++] } : { done: true }),
        cancel: async () => {},
      };
    },
  };
  const client = new OpenRouterClient({ apiKey: "runtime-key", fetch: async () => ({ ok: true, body }) });
  const result = await client.streamChat({
    model: DEFAULT_MODEL,
    messages: [{ role: "user", content: "hi" }],
    onChunk: (chunk) => chunks.push(chunk),
  });
  assert.equal(result.fullText, "Hello world");
  assert.deepEqual(chunks, ["Hello", " world"]);
});

test("OpenRouter streaming chat accumulates tool calls", async () => {
  const body = {
    getReader() {
      let done = false;
      return {
        read: async () =>
          done
            ? { done: true }
            : ((done = true),
              {
                done: false,
                value: Buffer.from(
                  'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call-1","function":{"name":"get_studio_state","arguments":"{}"}}]}}]}\n\ndata: [DONE]\n\n'
                ),
              }),
        cancel: async () => {},
      };
    },
  };
  const client = new OpenRouterClient({
    apiKey: "runtime-key",
    fetch: async (_url, options) => {
      assert.match(options.body, /get_studio_state/);
      return { ok: true, body };
    },
  });
  const result = await client.streamChat({
    model: DEFAULT_MODEL,
    messages: [],
    tools: [{ type: "function", function: { name: "get_studio_state", parameters: { type: "object" } } }],
  });
  assert.equal(result.toolCalls[0].function.name, "get_studio_state");
  assert.equal(result.toolCalls[0].function.arguments, "{}");
});

test("OpenRouter retry policy handles 429 rate limit with exponential backoff and onRetry progress", async () => {
  let attempts = 0;
  const retryEvents = [];
  const body = {
    getReader() {
      let done = false;
      return {
        read: async () =>
          done
            ? { done: true }
            : ((done = true), { done: false, value: Buffer.from('data: {"choices":[{"delta":{"content":"Success after retry"}}]}\n\ndata: [DONE]\n\n') }),
        cancel: async () => {},
      };
    },
  };

  const client = new OpenRouterClient({
    apiKey: "runtime-key",
    initialBackoffMs: 10,
    maxBackoffMs: 50,
    fetch: async () => {
      attempts += 1;
      if (attempts === 1) {
        return {
          ok: false,
          status: 429,
          statusText: "Too Many Requests",
          headers: new Map([["retry-after", "0"]]),
          text: async () => "Rate limit exceeded",
        };
      }
      return { ok: true, body };
    },
  });

  const result = await client.streamChat({
    model: DEFAULT_MODEL,
    messages: [{ role: "user", content: "test retry" }],
    maxRetries: 2,
    onRetry: (evt) => retryEvents.push(evt),
  });

  assert.equal(attempts, 2);
  assert.equal(result.fullText, "Success after retry");
  assert.equal(retryEvents.length, 1);
  assert.equal(retryEvents[0].status, 429);
  assert.equal(retryEvents[0].isRateLimit, true);
});

test("OpenRouter streaming chat does NOT auto-retry after first content delta", async () => {
  let attempts = 0;
  const body = {
    getReader() {
      let step = 0;
      return {
        read: async () => {
          step += 1;
          if (step === 1) {
            return { done: false, value: Buffer.from('data: {"choices":[{"delta":{"content":"Partial output"}}]}\n') };
          }
          throw new Error("Connection reset mid-stream");
        },
        cancel: async () => {},
      };
    },
  };

  const client = new OpenRouterClient({
    apiKey: "runtime-key",
    initialBackoffMs: 10,
    fetch: async () => {
      attempts += 1;
      return { ok: true, body };
    },
  });

  await assert.rejects(
    async () => {
      await client.streamChat({
        model: DEFAULT_MODEL,
        messages: [{ role: "user", content: "test partial" }],
        maxRetries: 3,
      });
    },
    (err) => {
      assert.ok(err instanceof OpenRouterError);
      assert.equal(err.isPartial, true);
      assert.equal(err.partialText, "Partial output");
      return true;
    }
  );

  assert.equal(attempts, 1, "Should not attempt auto-retry after partial content was emitted");
});

test("OpenRouter cancellation aborts pending backoff delay immediately", async () => {
  const controller = new AbortController();
  const client = new OpenRouterClient({
    apiKey: "runtime-key",
    initialBackoffMs: 5000, // long delay
    fetch: async () => {
      return {
        ok: false,
        status: 429,
        statusText: "Rate limited",
        headers: new Map(),
        text: async () => "",
      };
    },
  });

  const chatPromise = client.streamChat({
    model: DEFAULT_MODEL,
    messages: [{ role: "user", content: "cancel test" }],
    signal: controller.signal,
    maxRetries: 3,
  });

  // Abort shortly after invocation during backoff sleep
  setTimeout(() => controller.abort(), 20);

  await assert.rejects(chatPromise, (err) => {
    assert.equal(err.message, "OpenRouter generation cancelled by user.");
    return true;
  });
});

test("OpenRouter settings persistence clamps bounds and excludes API keys", () => {
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), "abraxius-openrouter-"));
  const saved = saveOpenRouterSettings(dataDir, {
    apiKey: "must-not-persist",
    selectedModel: DEFAULT_MODEL,
    maxRetries: 15, // should clamp to 10
    maxBackoffSeconds: 300, // should clamp to 120
  });
  const raw = fs.readFileSync(path.join(dataDir, "openrouter-settings.json"), "utf8");
  assert.equal(saved.selectedModel, DEFAULT_MODEL);
  assert.equal(saved.maxRetries, 10);
  assert.equal(saved.maxBackoffSeconds, 120);
  assert.equal(raw.includes("must-not-persist"), false);

  const loaded = loadOpenRouterSettings(dataDir);
  assert.equal(loaded.endpoint, DEFAULT_ENDPOINT);
  assert.equal(loaded.maxRetries, 10);
  assert.equal(loaded.maxBackoffSeconds, 120);
  fs.rmSync(dataDir, { recursive: true, force: true });
});

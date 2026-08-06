const test = require("node:test");
const assert = require("node:assert");
const fs = require("fs");
const path = require("path");
const os = require("os");
const {
  AiLoopGuard,
  OllamaClient,
  preparePromptWithMemory,
  defaultOllamaSettings,
  loadOllamaSettings,
  saveOllamaSettings,
} = require("../lib/ollama");

test("Ollama API model discovery & parsing", async () => {
  const mockFetch = async (url) => {
    assert.strictEqual(url, "http://127.0.0.1:11434/api/tags");
    return {
      ok: true,
      status: 200,
      json: async () => ({
        models: [
          {
            name: "llama3.2:latest",
            size: 2000000000,
            details: { parameter_size: "3B", context_length: 8192 },
          },
          {
            name: "cloud-model:latest",
            size: 5000000000,
            remote_host: "https://cloud.ollama.com",
            details: { parameter_size: "70B", context_length: 32768, remote: true },
          },
        ],
      }),
    };
  };

  const client = new OllamaClient({ endpoint: "http://127.0.0.1:11434", fetch: mockFetch });
  const models = await client.listModels();

  assert.strictEqual(models.length, 2);
  assert.strictEqual(models[0].name, "llama3.2:latest");
  assert.strictEqual(models[0].parameterSize, "3B");
  assert.strictEqual(models[0].isRemote, false);

  assert.strictEqual(models[1].name, "cloud-model:latest");
  assert.strictEqual(models[1].isRemote, true);
});

test("Ollama streaming chat chunks parsing", async () => {
  const mockChunks = [
    JSON.stringify({ message: { role: "assistant", content: "Hello " }, done: false }) + "\n",
    JSON.stringify({ message: { role: "assistant", content: "world!" }, done: true }) + "\n",
  ];

  const mockFetch = async (url, options) => {
    assert.strictEqual(url, "http://127.0.0.1:11434/api/chat");
    const parsedBody = JSON.parse(options.body);
    assert.strictEqual(parsedBody.model, "llama3.2:latest");
    assert.strictEqual(parsedBody.stream, true);

    const encoder = new TextEncoder();
    let index = 0;
    return {
      ok: true,
      status: 200,
      body: {
        getReader: () => ({
          read: async () => {
            if (index < mockChunks.length) {
              const chunk = mockChunks[index++];
              return { done: false, value: encoder.encode(chunk) };
            }
            return { done: true, value: undefined };
          },
          cancel: async () => {},
        }),
      },
    };
  };

  const client = new OllamaClient({ endpoint: "http://127.0.0.1:11434", fetch: mockFetch });
  const receivedChunks = [];
  const result = await client.streamChat({
    model: "llama3.2:latest",
    messages: [{ role: "user", content: "Hi" }],
    onChunk: (c) => receivedChunks.push(c),
  });

  assert.strictEqual(result.fullText, "Hello world!");
  assert.deepStrictEqual(receivedChunks, ["Hello ", "world!"]);
});

test("Ollama offline & error handling", async () => {
  const mockFetch404 = async () => ({
    ok: false,
    status: 404,
    statusText: "Not Found",
    text: async () => JSON.stringify({ error: "Model 'nonexistent' not found" }),
  });

  const client = new OllamaClient({ endpoint: "http://127.0.0.1:11434", fetch: mockFetch404 });

  await assert.rejects(
    async () => {
      await client.listModels();
    },
    (err) => err.message.includes("Ollama API HTTP 404")
  );

  await assert.rejects(
    async () => {
      await client.streamChat({ model: "nonexistent" });
    },
    (err) => err.message.includes("Model 'nonexistent' not found")
  );

  await assert.rejects(
    async () => {
      await client.streamChat({ model: "" });
    },
    (err) => err.message.includes("No model specified")
  );
});

test("Ollama stream cancellation", async () => {
  const controller = new AbortController();

  const mockFetch = async () => {
    return {
      ok: true,
      status: 200,
      body: {
        getReader: () => ({
          read: async () => {
            controller.abort();
            throw new DOMException("The operation was aborted", "AbortError");
          },
          cancel: async () => {},
        }),
      },
    };
  };

  const client = new OllamaClient({ endpoint: "http://127.0.0.1:11434", fetch: mockFetch });

  await assert.rejects(
    async () => {
      await client.streamChat({
        model: "llama3.2:latest",
        signal: controller.signal,
      });
    },
    (err) => err.message.includes("cancelled")
  );
});

test("AiLoopGuard anti-doom-loop detection", () => {
  const guard = new AiLoopGuard({ repetitions: 4, minimumSpanLength: 60, maximumSpanLength: 512 });

  // A repeated pattern of >60 chars with >12 letters
  const pattern = "This is a repeating test line with enough characters and letters to trigger the loop guard algorithm. ";
  assert(pattern.length >= 60);

  guard.append("Start of response. ");
  assert.strictEqual(guard.detectedLoop, null);

  for (let i = 0; i < 4; i++) {
    guard.append(pattern);
  }

  assert.notStrictEqual(guard.detectedLoop, null);
  assert(guard.detectedLoop.includes("repeating test line"));
});

test("Ollama settings persistence & safety", () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "ollama-test-"));
  try {
    const defaults = loadOllamaSettings(tmpDir);
    assert.strictEqual(defaults.enabled, true);
    assert.strictEqual(defaults.ptyAccessGranted, false);
    assert.strictEqual(defaults.endpoint, "http://127.0.0.1:11434");

    const saved = saveOllamaSettings(tmpDir, {
      selectedModel: "llama3.2",
      temperature: 0.2,
      ptyAccessGranted: true,
      apiKey: "secret_12345",
    });

    assert.strictEqual(saved.selectedModel, "llama3.2");
    assert.strictEqual(saved.temperature, 0.2);
    assert.strictEqual(saved.apiKey, undefined);

    const reloaded = loadOllamaSettings(tmpDir);
    assert.strictEqual(reloaded.selectedModel, "llama3.2");
    assert.strictEqual(reloaded.temperature, 0.2);
    assert.strictEqual(reloaded.ptyAccessGranted, true);
    assert.strictEqual(reloaded.apiKey, undefined);
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});

test("Memory Core retrieval & private policy injection", async () => {
  const mockOrchestrator = {
    searchMemories: async ({ isLocalModel }) => ({
      records: [
        { id: "1", type: "project_fact", scope: "project", content: "The place file uses ServerScriptService for main game logic.", sensitivity: "normal" },
        { id: "2", type: "preference", scope: "private", content: "User private note", sensitivity: "private" },
      ],
    }),
  };

  // Local model -> private memories allowed
  const localRes = await preparePromptWithMemory("Explain architecture", {
    memoryOrchestrator: mockOrchestrator,
    projectId: "/home/user/project",
    isRemoteModel: false,
  });

  assert.strictEqual(localRes.memoryCount, 2);
  assert(localRes.prompt.includes("<abraxius_memory>"));
  assert(localRes.prompt.includes("ServerScriptService"));
  assert(localRes.privacyNotice.includes("Local execution"));

  // Remote model -> private memories excluded under policy
  const remoteRes = await preparePromptWithMemory("Explain architecture", {
    memoryOrchestrator: mockOrchestrator,
    projectId: "/home/user/project",
    isRemoteModel: true,
  });

  assert.strictEqual(remoteRes.memoryCount, 1);
  assert(remoteRes.prompt.includes("ServerScriptService"));
  assert(!remoteRes.prompt.includes("User private note"));
  assert(remoteRes.privacyNotice.includes("Remote model"));
});

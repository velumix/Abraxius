"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { OllamaClient } = require("../lib/ollama");

function scrubSecrets(rawText) {
  if (typeof rawText !== "string" || !rawText) return rawText;
  return rawText
    .replace(/\b[0-9a-f]{64}\b/gi, "[REDACTED_SECRET_TOKEN]")
    .replace(/(ABRAXIUS_[A-Z0-9_]*|TOKEN|SECRET|API_KEY)=['"]?[A-Za-z0-9_\-\.]{16,}['"]?/gi, "$1=[REDACTED]");
}

test("scrubSecrets masks tokens, secrets, and environment credentials", () => {
  const secretToken = "a1b2c3d4e5f60718293a4b5c6d7e8f901a2b3c4d5e6f7081920a1b2c3d4e5f60";
  const rawOutput = `Connected to Antigravity. Token is ${secretToken}. ENV: ABRAXIUS_AGY_TOKEN=abc123def456ghi789jkl`;

  const scrubbed = scrubSecrets(rawOutput);

  assert.equal(scrubbed.includes(secretToken), false);
  assert.equal(scrubbed.includes("ABRAXIUS_AGY_TOKEN=abc123def456ghi789jkl"), false);
  assert.ok(scrubbed.includes("[REDACTED_SECRET_TOKEN]"));
  assert.ok(scrubbed.includes("ABRAXIUS_AGY_TOKEN=[REDACTED]"));
});

test("scrubSecrets preserves safe terminal and code text", () => {
  const safeText = "Connecting to http://127.0.0.1:13472. PTY 12345 ready. Output: print('Hello Roblox!')";
  assert.equal(scrubSecrets(safeText), safeText);
});

test("OllamaClient.pullModel streams progress and completes successfully", async () => {
  const mockChunks = [
    JSON.stringify({ status: "pulling manifest" }) + "\n",
    JSON.stringify({ status: "downloading sha256:123", total: 1000, completed: 500 }) + "\n",
    JSON.stringify({ status: "verifying sha256:123", total: 1000, completed: 1000 }) + "\n",
    JSON.stringify({ status: "success" }) + "\n",
  ];

  const mockFetch = async () => {
    let index = 0;
    const encoder = new TextEncoder();
    return {
      ok: true,
      body: {
        getReader() {
          return {
            async read() {
              if (index >= mockChunks.length) {
                return { done: true, value: undefined };
              }
              const chunk = mockChunks[index++];
              return { done: false, value: encoder.encode(chunk) };
            },
          };
        },
      },
    };
  };

  const client = new OllamaClient({ fetch: mockFetch });
  const progressReports = [];

  const res = await client.pullModel({
    model: "qwen2.5-coder:7b",
    onProgress: (p) => progressReports.push(p),
  });

  assert.equal(res.ok, true);
  assert.equal(progressReports.length, 4);
  assert.equal(progressReports[0].status, "pulling manifest");
  assert.equal(progressReports[1].percent, 50);
  assert.equal(progressReports[2].percent, 100);
});

test("index.html contains mandatory Antigravity, Ollama, and OpenRouter workspace UI components", () => {
  const htmlPath = path.join(__dirname, "../app/Abraxius.Linux/renderer/index.html");
  const html = fs.readFileSync(htmlPath, "utf8");

  // Check Antigravity header elements
  assert.ok(html.includes('id="agy-dot"'), "Antigravity status dot");
  assert.ok(html.includes('id="agy-permission-dot"'), "Antigravity permission status dot");
  assert.ok(html.includes('id="agy-search-bar"'), "Antigravity terminal search bar");
  assert.ok(html.includes('id="agy-toggle-search"'), "Antigravity terminal search button");

  // Check Ollama header elements
  assert.ok(html.includes('id="ollama-dot"'), "Ollama status dot");
  assert.ok(html.includes('id="ollama-pty-dot"'), "Ollama PTY status dot");
  assert.ok(html.includes('id="ollama-access-badge"'), "Ollama access button");
  assert.ok(html.includes('id="ollama-access-toggle"'), "Ollama access toggle");
  assert.ok(html.includes("does not disable Electron sandboxing"), "Ollama permission safety copy");
  assert.ok(html.includes('id="ollama-open-pull-btn"'), "Ollama open pull button");
  assert.ok(html.includes('id="ollama-pull-bar"'), "Ollama model pull bar");
  assert.ok(html.includes('id="ollama-search-bar"'), "Ollama terminal search bar");

  assert.ok(html.includes('data-page="openrouter"'), "OpenRouter navigation tab");
  assert.ok(html.includes('id="openrouter-dot"'), "OpenRouter status dot");
  assert.ok(html.includes('id="openrouter-api-key"'), "OpenRouter API key field");
  assert.ok(html.includes('id="openrouter-model-select"'), "OpenRouter model selector");
  assert.ok(html.includes('id="openrouter-prompt"'), "OpenRouter prompt field");
  assert.ok(html.includes('id="openrouter-activity"'), "OpenRouter activity console");
  assert.ok(html.includes("openrouter-settings-button"), "OpenRouter gear settings button");
  assert.ok(html.includes('id="openrouter-yolo-mode"'), "OpenRouter YOLO mode switch");

  // Check script tags for xterm addons
  assert.ok(html.includes("@xterm/addon-fit"), "fit addon script tag");
  assert.ok(html.includes("@xterm/addon-web-links"), "web-links addon script tag");
  assert.ok(html.includes("@xterm/addon-search"), "search addon script tag");
});

test("xterm dependencies exist in package.json and node_modules", () => {
  const pkgPath = path.join(__dirname, "../package.json");
  const pkg = JSON.parse(fs.readFileSync(pkgPath, "utf8"));

  assert.ok(pkg.dependencies["@xterm/xterm"], "@xterm/xterm dependency");
  assert.ok(pkg.dependencies["@xterm/addon-fit"], "@xterm/addon-fit dependency");
  assert.ok(pkg.dependencies["@xterm/addon-web-links"], "@xterm/addon-web-links dependency");
  assert.ok(pkg.dependencies["@xterm/addon-search"], "@xterm/addon-search dependency");

  const webLinksLib = path.join(__dirname, "../node_modules/@xterm/addon-web-links/lib/addon-web-links.js");
  const searchLib = path.join(__dirname, "../node_modules/@xterm/addon-search/lib/addon-search.js");

  assert.ok(fs.existsSync(webLinksLib), "addon-web-links.js exists");
  assert.ok(fs.existsSync(searchLib), "addon-search.js exists");
});

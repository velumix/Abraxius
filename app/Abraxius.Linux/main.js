const { app, BrowserWindow, ipcMain, Menu, Tray, nativeImage, shell, safeStorage } = require("electron");
const { spawn } = require("child_process");
const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { AgySession, createBridgeServer, resolveAgyCommand } = require("./antigravity/src");
if (app && typeof app.setName === "function") {
  app.setName("Abraxius");
}
const ROOT = path.resolve(__dirname, "../..");
const {
  OllamaClient,
  OllamaSession,
  resolveOllamaCommand,
  loadOllamaSettings,
  saveOllamaSettings,
  preparePromptWithMemory,
} = require(path.join(ROOT, "lib/ollama"));
const {
  OpenRouterClient,
  DEFAULT_MODEL: DEFAULT_OPENROUTER_MODEL,
  loadOpenRouterSettings,
  saveOpenRouterSettings,
} = require(path.join(ROOT, "lib/openrouter"));
const { MCPClient } = require(path.join(ROOT, "client"));
const {
  NvidiaNimClient,
  DEFAULT_ENDPOINT: DEFAULT_NVIDIA_NIM_ENDPOINT,
  DEFAULT_MODEL: DEFAULT_NVIDIA_NIM_MODEL,
} = require(path.join(ROOT, "lib/nvidia-nim"));
const {
  createNimBridgeServer,
  saveNimBridgeInfo,
} = require(path.join(ROOT, "lib/nvidia-nim-bridge"));
const { researchWeb, formatResearchContext } = require(path.join(ROOT, "lib/ollama-research"));
const { runOllamaAgent } = require(path.join(ROOT, "lib/ollama-agent"));

const API = "http://127.0.0.1:13470";
const DATA = app && typeof app.getPath === "function" ? path.join(app.getPath("userData"), "linux") : path.join(os.tmpdir(), "abraxius-linux");
const LOG = path.join(DATA, "abraxius-host.log");
const AUTOSTART = path.join(os.homedir(), ".config", "autostart", "abraxius.desktop");
let AGY_API = "http://127.0.0.1:13472";
const AGY_TOKEN_FILE = path.join(DATA, "antigravity-token");
const AGY_SETTINGS_FILE = path.join(DATA, "antigravity-settings.json");
const OPENROUTER_KEY_FILE = path.join(DATA, "openrouter-api-key.enc");
const NVIDIA_NIM_KEY_FILE = path.join(DATA, "nvidia-nim-api-key.enc");
const NVIDIA_NIM_SETTINGS_FILE = path.join(DATA, "nvidia-nim-settings.json");
let window;
let tray;
let host;
let ownsHost = false;
let agySession;
let agyBridge;
let agyDangerouslySkipPermissions = false;
let ollamaSession;
let ollamaDaemon;
let quitting = false;
const activeOllamaChats = new Map();
const activeOllamaPulls = new Map();
const activeOpenRouterChats = new Map();
const pendingOpenRouterApprovals = new Map();
let openRouterRuntimeKey = process.env.OPENROUTER_API_KEY || "";
let nvidiaNimRuntimeKey = process.env.NVIDIA_NIM_API_KEY || "";

const { PtyManager } = require("./pty-manager");
const ptyManager = new PtyManager();

ptyManager.on("event", (evt) => {
  if (typeof globalThis.__ABRAXIUS_EVENT__ === "function") {
    globalThis.__ABRAXIUS_EVENT__("pty-event", evt);
  }
  if (window && !window.isDestroyed()) {
    window.webContents.send("pty-event", evt);
  }
});
ptyManager.on("activity", (act) => {
  if (typeof globalThis.__ABRAXIUS_EVENT__ === "function") {
    globalThis.__ABRAXIUS_EVENT__("pty-activity", act);
  }
  if (window && !window.isDestroyed()) {
    window.webContents.send("pty-activity", act);
  }
});
ptyManager.on("activity-update", (act) => {
  if (typeof globalThis.__ABRAXIUS_EVENT__ === "function") {
    globalThis.__ABRAXIUS_EVENT__("pty-activity-update", act);
  }
  if (window && !window.isDestroyed()) {
    window.webContents.send("pty-activity-update", act);
  }
});

function restoreOpenRouterKey() {
  if (openRouterRuntimeKey || !safeStorage || typeof safeStorage.isEncryptionAvailable !== "function") return;
  try {
    if (safeStorage.isEncryptionAvailable() && fs.existsSync(OPENROUTER_KEY_FILE)) {
      const encoded = fs.readFileSync(OPENROUTER_KEY_FILE, "utf8").trim();
      if (encoded) openRouterRuntimeKey = safeStorage.decryptString(Buffer.from(encoded, "base64"));
    }
  } catch (error) {
    appendLog(`Failed to restore encrypted OpenRouter key: ${error.message}\n`);
  }
}

function restoreNvidiaNimKey() {
  if (nvidiaNimRuntimeKey || !safeStorage || typeof safeStorage.isEncryptionAvailable !== "function") return;
  try {
    if (safeStorage.isEncryptionAvailable() && fs.existsSync(NVIDIA_NIM_KEY_FILE)) {
      const encoded = fs.readFileSync(NVIDIA_NIM_KEY_FILE, "utf8").trim();
      if (encoded) nvidiaNimRuntimeKey = safeStorage.decryptString(Buffer.from(encoded, "base64"));
    }
  } catch (error) {
    appendLog(`Failed to restore encrypted NVIDIA NIM key: ${error.message}\n`);
  }
}

function persistNvidiaNimKey(key) {
  fs.mkdirSync(DATA, { recursive: true, mode: 0o700 });
  if (!key) {
    if (fs.existsSync(NVIDIA_NIM_KEY_FILE)) fs.unlinkSync(NVIDIA_NIM_KEY_FILE);
    return;
  }
  if (!safeStorage || !safeStorage.isEncryptionAvailable() || typeof safeStorage.encryptString !== "function") {
    throw new Error("Electron OS encryption is unavailable; the NVIDIA NIM key was not persisted.");
  }
  fs.writeFileSync(NVIDIA_NIM_KEY_FILE, safeStorage.encryptString(key).toString("base64"), { mode: 0o600 });
}

function defaultNvidiaNimSettings() {
  return {
    endpoint: DEFAULT_NVIDIA_NIM_ENDPOINT,
    model: DEFAULT_NVIDIA_NIM_MODEL,
    temperature: 1,
    topP: 0.95,
    maxTokens: 16384,
    reasoningBudget: 16384,
  };
}

function loadNvidiaNimSettings() {
  try {
    if (fs.existsSync(NVIDIA_NIM_SETTINGS_FILE)) return { ...defaultNvidiaNimSettings(), ...JSON.parse(fs.readFileSync(NVIDIA_NIM_SETTINGS_FILE, "utf8")) };
  } catch (error) { appendLog(`Failed to load NVIDIA NIM settings: ${error.message}\n`); }
  return defaultNvidiaNimSettings();
}

function saveNvidiaNimSettings(settings = {}) {
  const current = loadNvidiaNimSettings();
  const updated = { ...current, ...settings };
  fs.mkdirSync(DATA, { recursive: true, mode: 0o700 });
  fs.writeFileSync(NVIDIA_NIM_SETTINGS_FILE, JSON.stringify(updated, null, 2), { mode: 0o600 });
  return updated;
}

let nimBridge;

async function ensureNimBridge() {
  if (nimBridge) return nimBridge;
  const userDataDir = path.join(os.homedir(), ".config", "Abraxius");
  const tokenFile = path.join(DATA, "nvidia-nim-token");
  fs.mkdirSync(DATA, { recursive: true, mode: 0o700 });
  let token;
  if (fs.existsSync(tokenFile)) {
    token = fs.readFileSync(tokenFile, "utf8").trim();
  } else {
    token = crypto.randomBytes(32).toString("hex");
    fs.writeFileSync(tokenFile, `${token}\n`, { mode: 0o600 });
  }
  try { fs.chmodSync(tokenFile, 0o600); } catch {}

  nimBridge = createNimBridgeServer({
    getApiKey: () => nvidiaNimRuntimeKey,
    getSettings: loadNvidiaNimSettings,
    token,
    onChatStart: (data) => {
      if (window && !window.isDestroyed() && !window.webContents.isDestroyed()) {
        window.webContents.send("nvidia-nim-chat-start", data);
      }
    },
    onReasoning: (data) => {
      if (window && !window.isDestroyed() && !window.webContents.isDestroyed()) {
        window.webContents.send("nvidia-nim-reasoning", data);
      }
    },
    onChunk: (data) => {
      if (window && !window.isDestroyed() && !window.webContents.isDestroyed()) {
        window.webContents.send("nvidia-nim-chunk", data);
      }
    },
    onChatEnd: (data) => {
      if (window && !window.isDestroyed() && !window.webContents.isDestroyed()) {
        window.webContents.send("nvidia-nim-chat-end", data);
      }
    },
  });

  try {
    await nimBridge.listen();
    saveNimBridgeInfo(userDataDir, {
      port: nimBridge.port,
      token,
    });
  } catch (error) {
    appendLog(`NVIDIA NIM bridge listen error: ${error.stack || error}\n`);
  }
  return nimBridge;
}

async function stopNimBridge() {
  const bridge = nimBridge;
  nimBridge = undefined;
  if (bridge) await bridge.close().catch(() => {});
}

function persistOpenRouterKey(key) {
  try {
    fs.mkdirSync(DATA, { recursive: true, mode: 0o700 });
    if (!key) {
      if (fs.existsSync(OPENROUTER_KEY_FILE)) fs.unlinkSync(OPENROUTER_KEY_FILE);
      return;
    }
    if (!safeStorage || !safeStorage.isEncryptionAvailable() || typeof safeStorage.encryptString !== "function") {
      throw new Error("Electron OS encryption is unavailable; the key was not persisted.");
    }
    fs.writeFileSync(OPENROUTER_KEY_FILE, safeStorage.encryptString(key).toString("base64"), { mode: 0o600 });
  } catch (error) {
    appendLog(`Failed to persist encrypted OpenRouter key: ${error.message}\n`);
    throw error;
  }
}

async function getOpenRouterTools(allowActions = false) {
  try {
    const response = await new MCPClient().tools();
    const workspaceTools = [
      { type: "function", function: { name: "abraxius_workspace_read", description: "Read a text file from the Abraxius repository. Read-only.", parameters: { type: "object", required: ["path"], properties: { path: { type: "string" } } } } },
      { type: "function", function: { name: "abraxius_workspace_search", description: "Search text in the Abraxius repository. Read-only.", parameters: { type: "object", required: ["query"], properties: { query: { type: "string" }, path: { type: "string" } } } } },
    ];
    if (allowActions) workspaceTools.push({ type: "function", function: { name: "abraxius_workspace_replace", description: "Edit one Abraxius repository text file using an exact old-text/new-text replacement. This writes code and requires user approval unless YOLO mode is enabled.", parameters: { type: "object", required: ["path", "oldText", "newText"], properties: { path: { type: "string" }, oldText: { type: "string" }, newText: { type: "string" } } } } });
    return [...workspaceTools, ...(response?.tools || [])]
      .filter((tool) => tool?.name && (tool.annotations?.readOnlyHint === true || (allowActions && tool.annotations?.destructiveHint !== true)))
      .map((tool) => ({
        type: "function",
        function: {
          name: tool.name,
          description: String(tool.description || "").slice(0, 4000),
          parameters: tool.inputSchema || { type: "object", properties: {} },
        },
      }));
  } catch (error) {
    appendLog(`OpenRouter tool discovery unavailable: ${error.message}\n`);
    return [];
  }
}

function resolveWorkspaceFile(relativePath) {
  const candidate = path.resolve(ROOT, String(relativePath || ""));
  if (candidate !== ROOT && !candidate.startsWith(`${ROOT}${path.sep}`)) throw new Error("Workspace path must stay inside the Abraxius repository.");
  const relative = path.relative(ROOT, candidate);
  if (/^(\.git|node_modules)([\\/]|$)/i.test(relative) || /(^|[\\/])(?:\.env|.*(?:secret|token|api[-_]?key).*)$/i.test(relative)) throw new Error("That workspace path is protected.");
  return candidate;
}

function workspaceToolCall(name, args) {
  const filePath = resolveWorkspaceFile(args.path);
  if (name === "abraxius_workspace_read") {
    const stat = fs.statSync(filePath);
    if (!stat.isFile()) throw new Error("Workspace path is not a file.");
    return { path: path.relative(ROOT, filePath), content: fs.readFileSync(filePath, "utf8").slice(0, 120000) };
  }
  if (name === "abraxius_workspace_replace") {
    const source = fs.readFileSync(filePath, "utf8");
    if (!String(args.oldText)) throw new Error("oldText is required.");
    const occurrences = source.split(args.oldText).length - 1;
    if (occurrences !== 1) throw new Error(`Expected exactly one oldText match; found ${occurrences}.`);
    fs.writeFileSync(filePath, source.replace(args.oldText, args.newText), "utf8");
    return { ok: true, path: path.relative(ROOT, filePath), changed: true };
  }
  if (name === "abraxius_workspace_search") {
    const root = args.path ? resolveWorkspaceFile(args.path) : ROOT;
    const query = String(args.query || "");
    if (!query) throw new Error("query is required.");
    const results = [];
    const visit = (dir) => {
      if (results.length >= 50) return;
      for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        if (/^(\.git|node_modules|build|dist)$/i.test(entry.name)) continue;
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) visit(full);
        else if (entry.isFile() && fs.statSync(full).size < 1000000) {
          const text = fs.readFileSync(full, "utf8");
          const index = text.toLowerCase().indexOf(query.toLowerCase());
          if (index >= 0) results.push({ path: path.relative(ROOT, full), excerpt: text.slice(Math.max(0, index - 120), index + query.length + 240) });
        }
      }
    };
    visit(fs.statSync(root).isDirectory() ? root : path.dirname(root));
    return { query, results };
  }
  throw new Error(`Unknown workspace tool: ${name}`);
}


function appendLog(chunk) {
  fs.mkdirSync(DATA, { recursive: true, mode: 0o700 });
  fs.appendFileSync(LOG, chunk.toString());
}

async function health() {
  const response = await fetch(`${API}/health`, { signal: AbortSignal.timeout(1200) });
  if (!response.ok) throw new Error(`Host returned HTTP ${response.status}`);
  return response.json();
}

function loadAntigravitySettings() {
  try {
    if (fs.existsSync(AGY_SETTINGS_FILE)) {
      const parsed = JSON.parse(fs.readFileSync(AGY_SETTINGS_FILE, "utf8"));
      if (typeof parsed?.dangerouslySkipPermissions === "boolean") {
        return parsed;
      }
    }
  } catch (error) {
    appendLog(`Failed to load antigravity-settings.json: ${error.message}\n`);
  }
  return { dangerouslySkipPermissions: false };
}

function saveAntigravitySettings(settings) {
  try {
    fs.mkdirSync(DATA, { recursive: true, mode: 0o700 });
    fs.writeFileSync(AGY_SETTINGS_FILE, JSON.stringify(settings, null, 2), { mode: 0o600 });
  } catch (error) {
    appendLog(`Failed to save antigravity-settings.json: ${error.message}\n`);
  }
}

function antigravityToken() {
  if (process.env.ABRAXIUS_AGY_TOKEN) return process.env.ABRAXIUS_AGY_TOKEN;
  fs.mkdirSync(DATA, { recursive: true, mode: 0o700 });
  let token;
  if (fs.existsSync(AGY_TOKEN_FILE)) {
    token = fs.readFileSync(AGY_TOKEN_FILE, "utf8").trim();
  } else {
    token = crypto.randomBytes(32).toString("hex");
    fs.writeFileSync(AGY_TOKEN_FILE, `${token}\n`, { mode: 0o600 });
  }
  try { fs.chmodSync(AGY_TOKEN_FILE, 0o600); } catch {}
  return token;
}

function relayAntigravity(type, payload) {
  if (payload?.error instanceof Error) payload = { ...payload, error: payload.error.message };
  if (typeof globalThis.__ABRAXIUS_EVENT__ === "function") {
    globalThis.__ABRAXIUS_EVENT__("antigravity-event", { type, payload });
  }
  if (window && !window.isDestroyed() && !window.webContents.isDestroyed()) {
    window.webContents.send("antigravity-event", { type, payload });
  }
}

async function ensureAntigravity(options = {}) {
  if (agySession && agyBridge) return { started: false, api: AGY_API, session: agySession.status() };
  if (typeof options.dangerouslySkipPermissions === "boolean") {
    agyDangerouslySkipPermissions = options.dangerouslySkipPermissions;
  } else {
    const saved = loadAntigravitySettings();
    agyDangerouslySkipPermissions = saved.dangerouslySkipPermissions;
  }

  const resolvedCommand = resolveAgyCommand(process.env.AGY_COMMAND);

  agySession = new AgySession({
    cwd: ROOT,
    command: resolvedCommand,
    dangerouslySkipPermissions: agyDangerouslySkipPermissions,
  });
  agyBridge = createBridgeServer({
    session: agySession,
    token: antigravityToken(),
    // Keep Antigravity HTTP separate from the Abraxius AI WebSocket (13473).
    port: 13474,
    fallbackPorts: [13474, 13475, 13476, 13477],
  });

  for (const eventName of [
    "connected", "exit", "fault", "output", "queued", "reconnecting", "request",
    "request-error", "response", "state",
  ]) {
    agySession.on(eventName, (payload) => relayAntigravity(eventName, payload));
  }

  try {
    await agyBridge.listen();
    AGY_API = `http://127.0.0.1:${agyBridge.port}`;
  } catch (error) {
    agySession = undefined;
    agyBridge = undefined;
    throw error;
  }
  agySession.start().catch((error) => {
    appendLog(`Antigravity connection failed: ${error.stack || error}\n`);
  });
  return { started: true, api: AGY_API, session: agySession.status(), tokenFile: AGY_TOKEN_FILE };
}

async function stopAntigravity() {
  const session = agySession;
  const bridge = agyBridge;
  agySession = undefined;
  agyBridge = undefined;
  if (session) await session.stop().catch(() => {});
  if (bridge) await bridge.close().catch(() => {});
}

async function setAntigravityPermissions(enabled) {
  const nextValue = enabled === true;
  saveAntigravitySettings({ dangerouslySkipPermissions: nextValue });
  if (agySession?.status().dangerouslySkipPermissions === nextValue) return agySession.status();
  agyDangerouslySkipPermissions = nextValue;
  await stopAntigravity();
  const result = await ensureAntigravity({ dangerouslySkipPermissions: nextValue });
  return result.session;
}

function relayOllamaPty(type, payload) {
  if (payload?.error instanceof Error) payload = { ...payload, error: payload.error.message };
  if (typeof globalThis.__ABRAXIUS_EVENT__ === "function") {
    globalThis.__ABRAXIUS_EVENT__("ollama-pty-event", { type, payload });
  }
  if (window && !window.isDestroyed() && !window.webContents.isDestroyed()) {
    window.webContents.send("ollama-pty-event", { type, payload });
  }
}

async function ensureOllamaSession(options = {}) {
  const settings = loadOllamaSettings(DATA);
  if (settings.ptyAccessGranted !== true) {
    return {
      state: "blocked",
      ready: false,
      busy: false,
      pid: null,
      model: settings.selectedModel || "",
      permissionGranted: false,
      reason: "Ollama local access is disabled. Enable it in the Ollama tab to start its PTY.",
    };
  }
  const selectedModel = options.model || settings.selectedModel || "qwen3.5:9b-q4_K_M";
  if (ollamaSession && (ollamaSession.status().ready || ollamaSession.status().state === "starting")) {
    if (options.model && ollamaSession.model !== options.model) {
      return ollamaSession.restart({ model: options.model });
    }
    return ollamaSession.status();
  }

  ollamaSession = new OllamaSession({
    cwd: ROOT,
    model: selectedModel,
    command: options.command,
    args: options.args,
  });

  for (const eventName of ["connected", "exit", "fault", "output", "state"]) {
    ollamaSession.on(eventName, (payload) => relayOllamaPty(eventName, payload));
  }

  try {
    const status = await ollamaSession.start();
    return status;
  } catch (error) {
    ollamaSession = undefined;
    throw error;
  }
}

async function ensureOllamaDaemon() {
  const settings = loadOllamaSettings(DATA);
  if (settings.enabled === false) return { started: false, disabled: true };
  const endpoint = settings.endpoint || "http://127.0.0.1:11434";
  const client = new OllamaClient({ endpoint });
  try {
    await client.listModels();
    void warmOllamaModel(endpoint, settings.selectedModel || "qwen3.5:9b-q4_K_M");
    return { started: false, ready: true, owned: false, endpoint };
  } catch {}

  let parsed;
  try { parsed = new URL(endpoint); } catch { throw new Error(`Invalid Ollama endpoint: ${endpoint}`); }
  if (!/^(127\.0\.0\.1|localhost|::1)$/i.test(parsed.hostname)) {
    return { started: false, ready: false, owned: false, endpoint, reason: "non-local endpoint" };
  }
  if (ollamaDaemon && !ollamaDaemon.killed) return { started: false, ready: false, owned: true, endpoint };

  const command = resolveOllamaCommand();
  const host = `${parsed.hostname.includes(":") ? `[${parsed.hostname}]` : parsed.hostname}:${parsed.port || 11434}`;
  ollamaDaemon = spawn(command, ["serve"], {
    cwd: ROOT,
    env: { ...process.env, OLLAMA_HOST: host },
    stdio: ["ignore", "ignore", "pipe"],
  });
  ollamaDaemon.stderr?.on("data", (chunk) => appendLog(`Ollama: ${chunk.toString().slice(-2000)}`));
  ollamaDaemon.on("exit", () => { ollamaDaemon = undefined; });

  const deadline = Date.now() + 20_000;
  while (Date.now() < deadline) {
    try {
      await client.listModels();
      void warmOllamaModel(endpoint, settings.selectedModel || "qwen3.5:9b-q4_K_M");
      return { started: true, ready: true, owned: true, pid: ollamaDaemon.pid, endpoint };
    } catch { await new Promise((resolve) => setTimeout(resolve, 300)); }
  }
  throw new Error("Ollama daemon did not become ready within 20 seconds");
}

// Keep the selected local model resident so the first chatbot request does
// not pay the full model-load cost. This is intentionally asynchronous: app
// startup remains responsive while Ollama warms the model in the background.
async function warmOllamaModel(endpoint, model) {
  try {
    const response = await fetch(`${endpoint.replace(/\/$/, "")}/api/generate`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ model, prompt: "", stream: false, keep_alive: "10m", options: { num_predict: 1 } }),
      signal: AbortSignal.timeout(120000),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    appendLog(`Ollama model warmed: ${model}\n`);
    return true;
  } catch (error) {
    appendLog(`Ollama warm-up skipped: ${error.message}\n`);
    return false;
  }
}

async function stopOllamaDaemon() {
  const daemon = ollamaDaemon;
  ollamaDaemon = undefined;
  if (!daemon || daemon.killed) return;
  daemon.kill("SIGTERM");
}

async function stopOllamaSession() {
  const session = ollamaSession;
  ollamaSession = undefined;
  if (session) await session.stop().catch(() => {});
}


async function ensureHost() {
  try {
    await health();
    return { started: false };
  } catch {}
  host = spawn(process.execPath, [path.join(ROOT, "server.js"), "--daemon"], {
    cwd: ROOT,
    env: { ...process.env, ELECTRON_RUN_AS_NODE: "1" },
    stdio: ["ignore", "pipe", "pipe"],
  });
  ownsHost = true;
  host.stdout.on("data", appendLog);
  host.stderr.on("data", appendLog);
  host.on("exit", (code) => {
    appendLog(`\nHost exited with code ${code}\n`);
    host = undefined;
    if (window && !window.isDestroyed() && !window.webContents.isDestroyed()) {
      window.webContents.send("host-exit", code);
    }
  });
  for (let attempt = 0; attempt < 30; attempt++) {
    await new Promise((resolve) => setTimeout(resolve, 150));
    try { await health(); return { started: true }; } catch {}
  }
  throw new Error(`Abraxius host did not become ready. See ${LOG}`);
}

function runCli(args) {
  const allowed = new Set(["status", "plugin", "pull", "push", "pending", "ai-context"]);
  const commandStr = `abraxius ${args.join(" ")}`;
  if (!allowed.has(args[0])) {
    return Promise.resolve({
      ok: false,
      code: null,
      signal: null,
      error: "Command is not available in the Linux UI",
      output: "",
      stdout: "",
      stderr: "",
      command: commandStr,
    });
  }
  return new Promise((resolve) => {
    const child = spawn(process.execPath, [path.join(ROOT, "cli.js"), ...args], {
      cwd: ROOT,
      env: { ...process.env, ELECTRON_RUN_AS_NODE: "1", NO_COLOR: "1" },
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => { stdout += chunk; });
    child.stderr.on("data", (chunk) => { stderr += chunk; });
    child.on("error", (error) => {
      resolve({
        ok: false,
        code: null,
        signal: null,
        error: error.message,
        output: "",
        stdout: "",
        stderr: "",
        command: commandStr,
      });
    });
    child.on("exit", (code, signal) => {
      const cleanStdout = stdout.trim();
      const cleanStderr = stderr.trim();
      if (code === 0) {
        resolve({
          ok: true,
          code: 0,
          signal: null,
          output: cleanStdout,
          stdout: cleanStdout,
          stderr: cleanStderr,
          command: commandStr,
        });
      } else {
        const primaryError = cleanStderr
          ? cleanStderr.split("\n")[0]
          : cleanStdout
          ? cleanStdout.split("\n")[0]
          : code !== null && code !== undefined
          ? `Command exited with code ${code}`
          : `Command terminated by signal ${signal || "unknown"}`;
        resolve({
          ok: false,
          code: code ?? null,
          signal: signal ?? null,
          error: primaryError,
          output: (cleanStderr || cleanStdout || `Command exited ${code}`).trim(),
          stdout: cleanStdout,
          stderr: cleanStderr,
          command: commandStr,
        });
      }
    });
  });
}

async function api(route) {
  const response = await fetch(`${API}${route}`, { signal: AbortSignal.timeout(4000) });
  const body = await response.json();
  if (!response.ok) throw new Error(body.error || `HTTP ${response.status}`);
  return body;
}

function showWindow() {
  if (!window) return;
  window.show();
  window.focus();
}

function createWindow() {
  window = new BrowserWindow({
    width: 1180,
    height: 780,
    minWidth: 820,
    minHeight: 580,
    show: false,
    title: "Abraxius",
    icon: path.join(ROOT, "images/Logo.png"),
    backgroundColor: "#101418",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });
  window.removeMenu();
  window.loadFile(path.join(__dirname, "renderer/index.html"));
  window.once("ready-to-show", () => window.show());
  window.on("close", (event) => {
    if (!quitting) {
      event.preventDefault();
      window.hide();
    }
  });
  window.on("closed", () => { window = undefined; });
  window.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith("https://")) shell.openExternal(url);
    return { action: "deny" };
  });
}

function createTray() {
  const image = nativeImage.createFromPath(path.join(ROOT, "images/Tray.png")).resize({ width: 20, height: 20 });
  tray = new Tray(image);
  tray.setToolTip("Abraxius");
  tray.setContextMenu(Menu.buildFromTemplate([
    { label: "Open Abraxius", click: showWindow },
    { label: "Open host log", click: () => shell.openPath(LOG) },
    { type: "separator" },
    { label: "Quit Abraxius", click: () => { quitting = true; app.quit(); } },
  ]));
  tray.on("double-click", showWindow);
}

if (ipcMain && typeof ipcMain.handle === "function") {
  ipcMain.handle("health", () => health());
  ipcMain.handle("events", (_event, limit = 40) => api(`/plugin/events?limit=${Math.min(100, Number(limit) || 40)}`));
  ipcMain.handle("pending", () => api("/pending"));
  ipcMain.handle("run-cli", (_event, args) => runCli(Array.isArray(args) ? args.map(String) : []));
  ipcMain.handle("restart-host", async () => {
    if (ownsHost && host && !host.killed) host.kill("SIGTERM");
    else {
      try { await fetch(`${API}/shutdown`, { method: "POST" }); } catch {}
      await new Promise((resolve) => setTimeout(resolve, 350));
    }
    return ensureHost();
  });
  ipcMain.handle("open-log", () => shell.openPath(LOG));
  ipcMain.handle("open-data", () => { fs.mkdirSync(DATA, { recursive: true }); return shell.openPath(DATA); });

  // Abraxius Memory Core IPC Handlers
  ipcMain.handle("memory-health", () => api("/memory-core/health"));
  ipcMain.handle("memory-search", (_event, query, projectId) => api(`/memory-core/search?query=${encodeURIComponent(query || "")}&projectId=${encodeURIComponent(projectId || "")}`));
  ipcMain.handle("memory-records", (_event, scope, type, projectId, status) => {
    const params = new URLSearchParams();
    if (scope) params.set("scope", scope);
    if (type) params.set("type", type);
    if (projectId) params.set("projectId", projectId);
    if (status) params.set("status", status);
    return api(`/memory-core/records?${params.toString()}`);
  });
  ipcMain.handle("memory-add", async (_event, recordData) => {
    const res = await fetch(`${API}/memory-core/records`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(recordData || {}),
    });
    return res.json();
  });
  ipcMain.handle("memory-correct", async (_event, payload) => {
    const res = await fetch(`${API}/memory-core/records/correct`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload || {}),
    });
    return res.json();
  });
  ipcMain.handle("memory-forget", async (_event, id) => {
    const res = await fetch(`${API}/memory-core/records/forget`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id, confirm: true }),
    });
    return res.json();
  });
  ipcMain.handle("memory-proposed", (_event, projectId) => api(`/memory-core/proposed?projectId=${encodeURIComponent(projectId || "")}`));
  ipcMain.handle("memory-approve", async (_event, id) => {
    const res = await fetch(`${API}/memory-core/proposed/approve`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id }),
    });
    return res.json();
  });
  ipcMain.handle("memory-reject", async (_event, id) => {
    const res = await fetch(`${API}/memory-core/proposed/reject`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id, confirm: true }),
    });
    return res.json();
  });
  ipcMain.handle("memory-brief", (_event, projectId) => api(`/memory-core/project-brief?projectId=${encodeURIComponent(projectId || "")}`));
  ipcMain.handle("memory-settings-get", () => api("/memory-core/settings"));
  ipcMain.handle("memory-settings-save", async (_event, settings) => {
    const res = await fetch(`${API}/memory-core/settings`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(settings || {}),
    });
    return res.json();
  });
  ipcMain.handle("memory-index-dir", async (_event, dirPath) => {
    const res = await fetch(`${API}/memory-core/index-dir`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ dirPath }),
    });
    return res.json();
  });
  ipcMain.handle("antigravity-status", () => agySession
    ? { api: AGY_API, session: agySession.status(), tokenFile: AGY_TOKEN_FILE }
    : { api: AGY_API, session: { state: "stopped", ready: false, busy: false, queued: 0, dangerouslySkipPermissions: agyDangerouslySkipPermissions } });
  ipcMain.handle("antigravity-start", (_event, options = {}) => ensureAntigravity({
    dangerouslySkipPermissions: options.dangerouslySkipPermissions === true,
  }));
  ipcMain.handle("antigravity-permissions", (_event, enabled) => setAntigravityPermissions(enabled));
  ipcMain.handle("antigravity-prompt", async (_event, prompt, options = {}) => {
    if (!agySession) await ensureAntigravity(options);
    return agySession.send(String(prompt || ""), { timeoutMs: options.timeoutMs });
  });
  ipcMain.handle("antigravity-restart", async () => {
    if (!agySession) return ensureAntigravity();
    return agySession.restart();
  });
  ipcMain.handle("antigravity-interrupt", () => agySession?.interrupt() || false);
  ipcMain.handle("antigravity-resize", (_event, cols, rows) => agySession?.resize(cols, rows) || { resized: false, reason: "session_stopped" });
  ipcMain.handle("antigravity-write", (_event, data) => {
    if (!agySession) return { written: false, reason: "session_stopped" };
    if (typeof data !== "string") return { written: false, reason: "invalid_input" };
    return agySession.writeInput(data);
  });
  ipcMain.handle("antigravity-stop", async () => {
    await stopAntigravity();
    return { state: "stopped", ready: false };
  });

  // Ollama Workspace IPC Handlers
  ipcMain.handle("ollama-status", async () => {
    const settings = loadOllamaSettings(DATA);
    const client = new OllamaClient({ endpoint: settings.endpoint });
    const ptyStatus = ollamaSession ? ollamaSession.status() : { state: "stopped", ready: false, model: settings.selectedModel };
    try {
      const models = await client.listModels();
      return {
        online: true,
        endpoint: settings.endpoint,
        models,
        count: models.length,
        settings,
        ptySession: ptyStatus,
      };
    } catch (err) {
      return {
        online: false,
        endpoint: settings.endpoint,
        models: [],
        count: 0,
        error: err.message,
        settings,
        ptySession: ptyStatus,
      };
    }
  });

  ipcMain.handle("ollama-models", async (_event, endpointOverride) => {
    const settings = loadOllamaSettings(DATA);
    const targetEndpoint = endpointOverride || settings.endpoint;
    const client = new OllamaClient({ endpoint: targetEndpoint });
    return client.listModels();
  });

  ipcMain.handle("ollama-pull", async (event, payload = {}) => {
    if (loadOllamaSettings(DATA).ptyAccessGranted !== true) {
      throw new Error("Ollama local access is disabled. Enable it in the Ollama tab before pulling a model.");
    }
    const { model, endpoint } = payload;
    const settings = loadOllamaSettings(DATA);
    const targetEndpoint = endpoint || settings.endpoint;
    const client = new OllamaClient({ endpoint: targetEndpoint });
    const controller = new AbortController();
    const pullId = `${model}-${Date.now()}`;
    activeOllamaPulls.set(pullId, controller);
    try {
      const result = await client.pullModel({
        model,
        endpoint: targetEndpoint,
        signal: controller.signal,
        onProgress: (progress) => {
          if (!event.sender.isDestroyed()) {
            event.sender.send("ollama-pull-progress", { pullId, model, progress });
          }
        },
      });
      activeOllamaPulls.delete(pullId);
      return { ok: true, pullId, model, result };
    } catch (err) {
      activeOllamaPulls.delete(pullId);
      const isCancelled = controller.signal.aborted;
      return { ok: false, pullId, model, error: isCancelled ? "Model pull cancelled by user." : err.message, cancelled: isCancelled };
    }
  });

  ipcMain.handle("ollama-pull-cancel", (_event, pullId) => {
    if (pullId && activeOllamaPulls.has(pullId)) {
      activeOllamaPulls.get(pullId).abort();
      activeOllamaPulls.delete(pullId);
      return { ok: true, cancelled: true };
    }
    for (const controller of activeOllamaPulls.values()) {
      controller.abort();
    }
    activeOllamaPulls.clear();
    return { ok: true, cancelled: true };
  });

  ipcMain.handle("ollama-settings-get", () => loadOllamaSettings(DATA));

  ipcMain.handle("ollama-settings-save", (_event, settings) => saveOllamaSettings(DATA, settings));

  ipcMain.handle("ollama-pty-status", () => {
    const settings = loadOllamaSettings(DATA);
    return ollamaSession
      ? ollamaSession.status()
      : {
          state: settings.ptyAccessGranted === true ? "stopped" : "blocked",
          ready: false,
          busy: false,
          pid: null,
          model: settings.selectedModel || "",
          permissionGranted: settings.ptyAccessGranted === true,
          reason: settings.ptyAccessGranted === true
            ? null
            : "Ollama local access is disabled. Enable it in the Ollama tab to start its PTY.",
        };
  });
  ipcMain.handle("ollama-pty-start", (_event, options = {}) => ensureOllamaSession(options));
  ipcMain.handle("ollama-pty-restart", async (_event, options = {}) => {
    if (!ollamaSession) return ensureOllamaSession(options);
    return ollamaSession.restart(options);
  });
  ipcMain.handle("ollama-pty-stop", async () => {
    await stopOllamaSession();
    return { state: "stopped", ready: false };
  });
  ipcMain.handle("ollama-pty-interrupt", () => ollamaSession?.interrupt() || false);
  ipcMain.handle("ollama-pty-write", (_event, data) => {
    if (loadOllamaSettings(DATA).ptyAccessGranted !== true) {
      return { written: false, reason: "ollama_access_disabled" };
    }
    if (!ollamaSession) return { written: false, reason: "session_stopped" };
    if (typeof data !== "string") return { written: false, reason: "invalid_input" };
    return ollamaSession.writeInput(data);
  });

  ipcMain.handle("ollama-chat", async (event, payload = {}) => {
    const accessSettings = loadOllamaSettings(DATA);
    if (accessSettings.ptyAccessGranted !== true) {
      throw new Error("Ollama local access is disabled. Enable it in the Ollama tab before chatting.");
    }
    const {
      prompt,
      model,
      endpoint,
      temperature,
      numCtx,
      useMemory = true,
      sessionId = crypto.randomUUID ? crypto.randomUUID() : String(Date.now()),
      messages = [],
    } = payload;

    const settings = loadOllamaSettings(DATA);
    const targetEndpoint = endpoint || settings.endpoint;
    const client = new OllamaClient({ endpoint: targetEndpoint });
    const controller = new AbortController();

    activeOllamaChats.set(sessionId, { controller, client });

    try {
      let finalMessages = [...messages];
      let privacyNotice = "Direct prompt";
      let memoryCount = 0;

      if (useMemory) {
        let orchestrator = null;
        try {
          const { memoryOrchestrator } = require(path.join(ROOT, "server.js"));
          orchestrator = memoryOrchestrator;
        } catch {}

        if (orchestrator) {
          const memResult = await preparePromptWithMemory(prompt, {
            memoryOrchestrator: orchestrator,
            projectId: ROOT,
            cloudPolicy: orchestrator.settings?.cloudPolicy || "never_cloud",
          });
          finalMessages.push({ role: "user", content: memResult.prompt });
          privacyNotice = memResult.privacyNotice;
          memoryCount = memResult.memoryCount;
        } else {
          finalMessages.push({ role: "user", content: prompt });
        }
      } else {
        finalMessages.push({ role: "user", content: prompt });
      }

      if (!event.sender.isDestroyed()) {
        event.sender.send("ollama-chat-start", {
          sessionId,
          privacyNotice,
          memoryCount,
        });
      }

      if (payload.useInternet === true) {
        if (accessSettings.internetAccessGranted !== true) throw new Error("Ollama internet research is disabled. Enable it in the Ollama tab first.");
        const research = await researchWeb(prompt);
        finalMessages.push({ role: "user", content: `${prompt}\n\n${formatResearchContext(research)}` });
        if (!event.sender.isDestroyed()) event.sender.send("ollama-research", { sessionId, query: research.query, results: research.results });
      }

      const startTime = Date.now();
      const result = await client.streamChat({
        model: model || settings.selectedModel,
        messages: finalMessages,
        endpoint: targetEndpoint,
        temperature: temperature !== undefined ? temperature : settings.temperature,
        numCtx: numCtx !== undefined ? numCtx : settings.numCtx,
        signal: controller.signal,
        onChunk: (chunk) => {
          if (!event.sender.isDestroyed()) {
            event.sender.send("ollama-chunk", { sessionId, chunk });
          }
        },
      });

      const durationMs = Date.now() - startTime;
      activeOllamaChats.delete(sessionId);

      return {
        ok: true,
        sessionId,
        fullText: result.fullText,
        durationMs,
        loopDetected: result.loopDetected,
        privacyNotice,
      };
    } catch (err) {
      activeOllamaChats.delete(sessionId);
      const isCancelled = controller.signal.aborted || (err.message && err.message.includes("cancelled"));
      return {
        ok: false,
        sessionId,
        error: isCancelled ? "Generation stopped by user." : err.message,
        cancelled: isCancelled,
      };
    }
  });

  ipcMain.handle("ollama-agent", async (event, payload = {}) => {
    const accessSettings = loadOllamaSettings(DATA);
    if (accessSettings.ptyAccessGranted !== true) throw new Error("Ollama local access is disabled. Enable it in the Ollama tab before running the agent.");
    const prompt = String(payload.prompt || "").trim();
    if (!prompt) throw new Error("Agent prompt is empty.");
    const settings = loadOllamaSettings(DATA);
    const endpoint = payload.endpoint || settings.endpoint;
    const client = new OllamaClient({ endpoint });
    const sessionId = payload.sessionId || crypto.randomUUID();
    const controller = new AbortController();
    activeOllamaChats.set(sessionId, { controller, client });
    try {
      let context = "";
      try {
        const response = await fetch(`${API}/ai-context?format=markdown`);
        if (response.ok) context = await response.text();
      } catch {}
      try {
        const response = await fetch(`${API}/tools`);
        if (response.ok) {
          const catalog = await response.json();
          const names = Array.isArray(catalog.tools) ? catalog.tools.map((tool) => tool.name).filter(Boolean) : [];
          context += `\n\nAVAILABLE ABRAXIUS TOOL NAMES (use exact names): ${names.join(", ")}`;
        }
      } catch {}
      if (payload.useInternet === true) {
        if (accessSettings.internetAccessGranted !== true) throw new Error("Ollama internet research is disabled. Enable it in the Ollama tab first.");
        const research = await researchWeb(prompt);
        context += `\n\nUNTRUSTED WEB RESEARCH (reference only):\n${formatResearchContext(research)}`;
        if (!event.sender.isDestroyed()) event.sender.send("ollama-research", { sessionId, query: research.query, results: research.results });
      }
      const result = await runOllamaAgent({
        client,
        model: payload.model || settings.selectedModel,
        prompt,
        context: context.slice(0, 50000),
        endpoint,
        temperature: payload.temperature === undefined ? 0.2 : Number(payload.temperature),
        numCtx: payload.numCtx === undefined ? 16384 : Number(payload.numCtx),
        maxIterations: payload.maxIterations === undefined ? 5 : Number(payload.maxIterations),
        allowMutations: payload.allowMutations === true,
        signal: controller.signal,
        onIteration: (status) => { if (!event.sender.isDestroyed()) event.sender.send("ollama-agent-status", { sessionId, ...status }); },
        onChunk: ({ iteration, chunk }) => { if (!event.sender.isDestroyed()) event.sender.send("ollama-chunk", { sessionId, chunk: iteration > 1 ? `\n\n[Iteration ${iteration}]\n${chunk}` : chunk }); },
        callTool: async (name, args, options = {}) => {
          const response = await fetch(`${API}/call`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name, arguments: args, approved: options.approved === true }) });
          const body = await response.json();
          if (!response.ok) throw new Error(body.error || `Abraxius tool ${name} failed`);
          return body;
        },
      });
      return { ...result, sessionId };
    } catch (error) {
      return { ok: false, sessionId, error: controller.signal.aborted ? "Generation stopped by user." : error.message };
    } finally { activeOllamaChats.delete(sessionId); }
  });

  ipcMain.handle("nvidia-nim-status", () => {
    const settings = loadNvidiaNimSettings();
    return { ...settings, hasApiKey: Boolean(nvidiaNimRuntimeKey), remote: true };
  });
  ipcMain.handle("nvidia-nim-settings-get", () => ({ ...loadNvidiaNimSettings(), hasApiKey: Boolean(nvidiaNimRuntimeKey), apiKey: undefined }));
  ipcMain.handle("nvidia-nim-settings-save", (_event, settings = {}) => {
    if (typeof settings.apiKey === "string" && settings.apiKey.trim()) {
      nvidiaNimRuntimeKey = settings.apiKey.trim();
      persistNvidiaNimKey(nvidiaNimRuntimeKey);
    }
    if (settings.clearApiKey === true) {
      nvidiaNimRuntimeKey = "";
      persistNvidiaNimKey("");
    }
    const allowed = (({ endpoint, model, temperature, topP, maxTokens, reasoningBudget }) => ({ endpoint, model, temperature, topP, maxTokens, reasoningBudget }))(settings);
    return { ...saveNvidiaNimSettings(allowed), hasApiKey: Boolean(nvidiaNimRuntimeKey), apiKey: undefined };
  });
  ipcMain.handle("nvidia-nim-chat", async (_event, payload = {}) => {
    if (!nvidiaNimRuntimeKey) throw new Error("NVIDIA NIM API key is not configured. Add it in the NVIDIA NIM tab.");
    const bridge = await ensureNimBridge();
    const { promise } = bridge.submitJob({
      ...payload,
      source: payload.source || "ui",
    });
    return promise;
  });
  ipcMain.handle("nvidia-nim-cancel", (_event, sessionId) => {
    if (!nimBridge) return false;
    return nimBridge.cancelJob(sessionId);
  });

  ipcMain.handle("openrouter-status", async () => {
    const settings = loadOpenRouterSettings(DATA);
    return {
      endpoint: settings.endpoint,
      model: settings.selectedModel || DEFAULT_OPENROUTER_MODEL,
      hasApiKey: Boolean(openRouterRuntimeKey),
      remote: true,
    };
  });
  ipcMain.handle("openrouter-models", async (_event, options = {}) => {
    const settings = loadOpenRouterSettings(DATA);
    return new OpenRouterClient({ endpoint: settings.endpoint, apiKey: openRouterRuntimeKey }).listModels(options || {});
  });
  ipcMain.handle("openrouter-settings-get", () => {
    const settings = loadOpenRouterSettings(DATA);
    return { ...settings, hasApiKey: Boolean(openRouterRuntimeKey), apiKey: undefined };
  });
  ipcMain.handle("openrouter-settings-save", (_event, settings = {}) => {
    if (typeof settings.apiKey === "string" && settings.apiKey.trim()) {
      openRouterRuntimeKey = settings.apiKey.trim();
      persistOpenRouterKey(openRouterRuntimeKey);
    }
    if (settings.clearApiKey === true) {
      openRouterRuntimeKey = "";
      persistOpenRouterKey("");
    }
    return { ...saveOpenRouterSettings(DATA, settings), hasApiKey: Boolean(openRouterRuntimeKey), apiKey: undefined };
  });
  ipcMain.handle("openrouter-chat", async (event, payload = {}) => {
    if (!openRouterRuntimeKey) throw new Error("OpenRouter API key is not configured. Add it in the OpenRouter tab.");
    const settings = loadOpenRouterSettings(DATA);
    const sessionId = payload.sessionId || crypto.randomUUID();
    const controller = new AbortController();
    const client = new OpenRouterClient({
      endpoint: payload.endpoint || settings.endpoint,
      apiKey: openRouterRuntimeKey,
      maxRetries: settings.maxRetries,
      maxBackoffMs: (settings.maxBackoffSeconds || 30) * 1000,
    });
    activeOpenRouterChats.set(sessionId, controller);
    let privacyNotice = "Remote model: private memories excluded";
    let memoryCount = 0;
    try {
      let messages = Array.isArray(payload.messages) ? [...payload.messages] : [];
      if (payload.useMemory !== false) {
        try {
          const { memoryOrchestrator } = require(path.join(ROOT, "server.js"));
          const mem = await preparePromptWithMemory(payload.prompt || "", {
            memoryOrchestrator,
            projectId: ROOT,
            isRemoteModel: true,
            cloudPolicy: memoryOrchestrator.settings?.cloudPolicy || "never_cloud",
          });
          messages.push({ role: "user", content: mem.prompt });
          privacyNotice = mem.privacyNotice;
          memoryCount = mem.memoryCount;
        } catch { messages.push({ role: "user", content: payload.prompt || "" }); }
      } else messages.push({ role: "user", content: payload.prompt || "" });
      if (!event.sender.isDestroyed()) event.sender.send("openrouter-chat-start", { sessionId, privacyNotice, memoryCount });
      const model = payload.model || settings.selectedModel || DEFAULT_OPENROUTER_MODEL;
      let result;
      for (let round = 0; round < 4; round += 1) {
        const yoloMode = payload.yoloMode === true;
        const tools = payload.useTools === false ? [] : await getOpenRouterTools(payload.allowActions === true || yoloMode);
        result = await client.streamChat({
          model,
          messages,
          tools,
          temperature: payload.temperature ?? settings.temperature,
          signal: controller.signal,
          onChunk: (chunk) => { if (!event.sender.isDestroyed()) event.sender.send("openrouter-chunk", { sessionId, chunk }); },
          onRetry: (retryInfo) => { if (!event.sender.isDestroyed()) event.sender.send("openrouter-retry", { sessionId, ...retryInfo }); },
        });
        if (!result.toolCalls?.length) break;
        messages.push({ role: "assistant", content: result.fullText || null, tool_calls: result.toolCalls });
        for (const toolCall of result.toolCalls) {
          let args;
          try { args = JSON.parse(toolCall.function.arguments || "{}"); } catch { args = {}; }
          if (!event.sender.isDestroyed()) event.sender.send("openrouter-tool", { sessionId, name: toolCall.function.name, arguments: args });
          const toolDefinition = tools.find((tool) => tool.function.name === toolCall.function.name);
          if (!yoloMode && payload.allowActions === true && toolDefinition?.function?.description && /write|edit|delete|set|start|stop|execute|move|create|run/i.test(toolDefinition.function.description)) {
            const approvalId = crypto.randomUUID();
            const approved = await new Promise((resolve) => {
              pendingOpenRouterApprovals.set(approvalId, resolve);
              if (event.sender.isDestroyed()) { pendingOpenRouterApprovals.delete(approvalId); resolve(false); return; }
              event.sender.send("openrouter-tool-approval", { approvalId, sessionId, name: toolCall.function.name, arguments: args });
              setTimeout(() => { if (pendingOpenRouterApprovals.has(approvalId)) { pendingOpenRouterApprovals.delete(approvalId); resolve(false); } }, 60000);
            });
            if (!approved) {
              messages.push({ role: "tool", tool_call_id: toolCall.id, name: toolCall.function.name, content: "Tool action denied by user." });
              continue;
            }
          }
          const toolResult = toolCall.function.name.startsWith("abraxius_workspace_")
            ? workspaceToolCall(toolCall.function.name, args)
            : await new MCPClient().call(toolCall.function.name, args);
          if (!event.sender.isDestroyed()) event.sender.send("openrouter-tool-result", { sessionId, name: toolCall.function.name, result: toolResult });
          messages.push({ role: "tool", tool_call_id: toolCall.id, name: toolCall.function.name, content: JSON.stringify(toolResult) });
        }
      }
      return { ok: true, sessionId, fullText: result?.fullText || "", privacyNotice };
    } catch (error) {
      return {
        ok: false,
        sessionId,
        error: error.message,
        cancelled: controller.signal.aborted,
        isPartial: error.isPartial === true,
        partialText: error.partialText || "",
      };
    } finally { activeOpenRouterChats.delete(sessionId); }
  });
  ipcMain.handle("openrouter-tool-approval", (_event, approvalId, approved) => {
    const resolve = pendingOpenRouterApprovals.get(approvalId);
    if (!resolve) return false;
    pendingOpenRouterApprovals.delete(approvalId);
    resolve(approved === true);
    return true;
  });
  ipcMain.handle("openrouter-cancel", (_event, sessionId) => {
    const controller = activeOpenRouterChats.get(sessionId);
    if (!controller) return false;
    controller.abort(); activeOpenRouterChats.delete(sessionId); return true;
  });

  ipcMain.handle("ollama-cancel", (_event, sessionId) => {
    if (sessionId && activeOllamaChats.has(sessionId)) {
      const { controller } = activeOllamaChats.get(sessionId);
      controller.abort();
      activeOllamaChats.delete(sessionId);
      return { ok: true, cancelled: true };
    }
    for (const [id, { controller }] of activeOllamaChats.entries()) {
      controller.abort();
    }
    activeOllamaChats.clear();
    return { ok: true, cancelled: true };
  });

  ipcMain.handle("pty-list", () => ptyManager.listSessions());
  ipcMain.handle("pty-create", (_event, options = {}) => ptyManager.createSession(options));
  ipcMain.handle("pty-write", (_event, { id, data } = {}) => ptyManager.writeInput(id, data));
  ipcMain.handle("pty-resize", (_event, { id, cols, rows } = {}) => ptyManager.resize(id, cols, rows));
  ipcMain.handle("pty-stop", (_event, { id } = {}) => ptyManager.stopSession(id));
  ipcMain.handle("pty-restart", (_event, { id } = {}) => ptyManager.restartSession(id));
  ipcMain.handle("pty-close", (_event, { id } = {}) => ptyManager.closeSession(id));
  ipcMain.handle("pty-buffer", (_event, { id } = {}) => ptyManager.getBuffer(id));
  ipcMain.handle("pty-history", () => ptyManager.activityLog);

  ipcMain.handle("autostart", (_event, enabled) => {
    if (enabled) {
      fs.mkdirSync(path.dirname(AUTOSTART), { recursive: true });
      fs.writeFileSync(AUTOSTART, `[Desktop Entry]\nType=Application\nName=Abraxius\nTryExec=${process.execPath}\nExec="${process.execPath}" "${path.join(ROOT, "app/Abraxius.Linux/main.js")}"\nPath=${ROOT}\nIcon=${path.join(ROOT, "images/Logo.png")}\nTerminal=false\nX-GNOME-Autostart-enabled=true\n`);
    } else if (fs.existsSync(AUTOSTART)) {
      fs.unlinkSync(AUTOSTART);
    }
    return fs.existsSync(AUTOSTART);
  });
  ipcMain.handle("autostart-status", () => fs.existsSync(AUTOSTART));

  if (app && typeof app.requestSingleInstanceLock === "function") {
    const instanceLock = app.requestSingleInstanceLock();
    if (!instanceLock) app.quit();
    app.on("second-instance", showWindow);

    app.whenReady().then(async () => {
      if (!instanceLock) return;
      restoreOpenRouterKey();
      restoreNvidiaNimKey();
      createWindow();
      createTray();
      try { await ensureHost(); } catch (error) { appendLog(`${error.stack || error}\n`); }
      try { await ensureOllamaDaemon(); } catch (error) { appendLog(`Ollama startup failed: ${error.stack || error}\n`); }
      try { await ensureAntigravity(); } catch (error) { appendLog(`${error.stack || error}\n`); }
      try { await ensureNimBridge(); } catch (error) { appendLog(`${error.stack || error}\n`); }
    });
    process.on("SIGUSR1", () => agySession?.restart().catch((error) => appendLog(`Antigravity restart failed: ${error.stack || error}\n`)));
    process.on("SIGUSR2", () => agySession?.interrupt());
    app.on("activate", showWindow);
    app.on("window-all-closed", () => {});
    app.on("before-quit", () => {
      quitting = true;
      if (ownsHost && host && !host.killed) host.kill("SIGTERM");
      void stopAntigravity();
      void stopOllamaSession();
      void stopOllamaDaemon();
      void stopNimBridge();
    });
  }
}

module.exports = { runCli, health, ensureHost, ensureAntigravity, stopAntigravity, ensureOllamaDaemon, stopOllamaDaemon, ensureOllamaSession, stopOllamaSession, ensureNimBridge, stopNimBridge };

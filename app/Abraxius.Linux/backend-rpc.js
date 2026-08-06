// Headless compatibility host for the Tauri 2 desktop shell.
// It reuses the existing Linux backend handlers from main.js without starting
// Electron's window, tray, or lifecycle.
const Module = require("module");
const path = require("path");
const readline = require("readline");

const handlers = new Map();
const emit = (channel, value) => process.stdout.write(`${JSON.stringify({ type: "event", channel, value })}\n`);
const sender = { isDestroyed: () => false, send: emit };
globalThis.__ABRAXIUS_EVENT__ = emit;

const fakeElectron = {
  app: {
    getPath: () => path.join(process.env.XDG_CONFIG_HOME || path.join(require("os").homedir(), ".config"), "Abraxius"),
    setName: () => {},
    requestSingleInstanceLock: () => false,
    quit: () => {},
    on: () => {},
    whenReady: () => Promise.resolve(),
  },
  ipcMain: { handle: (name, fn) => handlers.set(name, fn) },
  BrowserWindow: class {},
  Menu: { buildFromTemplate: () => ({}) },
  Tray: class {},
  nativeImage: { createFromPath: () => ({ resize: () => ({}) }) },
  shell: { openPath: async () => "" },
  safeStorage: {
    isEncryptionAvailable: () => false,
    encryptString: () => Buffer.alloc(0),
    decryptString: () => "",
  },
};

const originalLoad = Module._load;
Module._load = function patchedLoad(request, parent, isMain) {
  if (request === "electron") return fakeElectron;
  return originalLoad.call(this, request, parent, isMain);
};

const linuxBackend = require(path.join(__dirname, "main.js"));

// Electron normally performs this in app.whenReady(). The Tauri shell owns
// readiness, so the headless adapter starts the shared host explicitly.
linuxBackend.ensureHost().catch((error) => emit("host-start-error", { error: error.message || String(error) }));

function invoke(name, args) {
  const handler = handlers.get(name);
  if (!handler) throw new Error(`Unknown backend method: ${name}`);
  return handler({ sender }, ...(Array.isArray(args) ? args : []));
}

const input = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });
input.on("line", async (line) => {
  let request;
  try { request = JSON.parse(line); } catch { return; }
  if (!request || request.type !== "call") return;
  try {
    const result = await invoke(request.name, request.args);
    process.stdout.write(`${JSON.stringify({ type: "result", id: request.id, ok: true, result })}\n`);
  } catch (error) {
    process.stdout.write(`${JSON.stringify({ type: "result", id: request.id, ok: false, error: error.message || String(error) })}\n`);
  }
});

process.on("SIGTERM", () => process.exit(0));

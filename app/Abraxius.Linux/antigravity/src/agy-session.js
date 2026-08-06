"use strict";

const { EventEmitter } = require("events");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { cleanTranscript, stripAnsi } = require("./terminal-text");
const { createEnvelope } = require("./protocol");

function isExecutable(filePath) {
  try {
    const stat = fs.statSync(filePath);
    if (!stat.isFile()) return false;
    fs.accessSync(filePath, fs.constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function resolveAgyCommand(command) {
  if (command && (command.includes("/") || command.includes("\\"))) {
    const resolved = path.resolve(command);
    if (isExecutable(resolved)) return resolved;
  }

  if (process.env.AGY_COMMAND && isExecutable(process.env.AGY_COMMAND)) {
    return process.env.AGY_COMMAND;
  }

  const binaryName = process.platform === "win32" ? "agy.exe" : "agy";

  const pathDirs = (process.env.PATH || "").split(path.delimiter).filter(Boolean);
  for (const dir of pathDirs) {
    const candidate = path.join(dir, binaryName);
    if (isExecutable(candidate)) return candidate;
  }

  const standardCandidates = [
    path.join(os.homedir(), ".local", "bin", binaryName),
    path.join(os.homedir(), ".cargo", "bin", binaryName),
    "/usr/local/bin/" + binaryName,
    "/usr/bin/" + binaryName,
  ];

  for (const candidate of standardCandidates) {
    if (isExecutable(candidate)) return candidate;
  }

  return command || path.join(os.homedir(), ".local", "bin", binaryName);
}

function shellQuote(value) {
  return `'${String(value).replace(/'/g, `'"'"'`)}'`;
}

function terminalQueryResponse(value) {
  const raw = String(value);
  const replies = [];

  for (const match of raw.matchAll(/\x1B\[\?(\d+)\$p/g)) {
    replies.push(`\x1B[?${match[1]};2$y`);
  }
  if (raw.includes("\x1B[?u")) replies.push("\x1B[?0u");
  if (raw.includes("\x1B[6n")) replies.push("\x1B[1;1R");
  if (raw.includes("\x1B[5n")) replies.push("\x1B[0n");
  if (raw.includes("\x1B[>c")) replies.push("\x1B[>0;0;0c");
  if (raw.includes("\x1B[c")) replies.push("\x1B[?1;2c");

  return replies.join("");
}

function defaultSpawnProcess(options) {
  if (process.platform !== "linux") {
    throw new Error("The built-in PTY transport currently requires Linux");
  }
  const pty = require("node-pty");
  const cols = Number(options.cols) || 120;
  const rows = Number(options.rows) || 40;
  const { NO_COLOR: _noColor, ...inheritedEnv } = process.env;
  return pty.spawn(options.command, options.args, {
    name: "xterm-256color",
    cols,
    rows,
    cwd: options.cwd,
    env: {
      ...inheritedEnv,
      TERM: "xterm-256color",
      COLORTERM: "truecolor",
      COLOR: "1",
      CLICOLOR: "1",
      CLICOLOR_FORCE: "1",
      COLUMNS: String(cols),
      LINES: String(rows),
    },
  });
}

class AgySession extends EventEmitter {
  constructor(options = {}) {
    super();
    this.command = resolveAgyCommand(options.command);
    this.args = Array.isArray(options.args) ? [...options.args] : [];
    if (options.dangerouslySkipPermissions && !this.args.includes("--dangerously-skip-permissions")) {
      this.args.push("--dangerously-skip-permissions");
    }
    this.cwd = options.cwd || process.cwd();
    this.startupTimeoutMs = options.startupTimeoutMs || 60_000;
    this.responseTimeoutMs = options.responseTimeoutMs || 10 * 60_000;
    this.autoReconnect = options.autoReconnect !== false;
    this.spawnProcess = options.spawnProcess || defaultSpawnProcess;
    const defaultPolicy = {
      initialDelayMs: 1_000,
      maxDelayMs: 30_000,
      backoffFactor: 2,
      maxAttempts: Infinity,
      jitter: false,
    };
    this.reconnectPolicy = { ...defaultPolicy, ...(options.reconnectPolicy || {}) };
    this.setTimeout = options.setTimeout || setTimeout;
    this.clearTimeout = options.clearTimeout || clearTimeout;

    this.child = null;
    this.state = "stopped";
    this.queue = [];
    this.active = null;
    this.startPromise = null;
    this.startResolve = null;
    this.startReject = null;
    this.startupTimer = null;
    this.startupWindow = "";
    this.trustPromptAccepted = false;
    this.reconnectTimer = null;
    this.reconnectAttempt = 0;
    this.reconnectDelay = 0;
    this.intentionalStop = false;
  }

  calculateReconnectDelay(attempt = this.reconnectAttempt) {
    const policy = this.reconnectPolicy;
    const exp = Math.max(0, attempt - 1);
    const baseDelay = Math.min(policy.maxDelayMs, policy.initialDelayMs * (policy.backoffFactor ** exp));
    if (typeof policy.jitter === "function") {
      return policy.jitter(baseDelay, attempt);
    }
    if (policy.jitter === true) {
      return Math.floor(baseDelay * (0.8 + Math.random() * 0.4));
    }
    return Math.floor(baseDelay);
  }

  status() {
    return {
      state: this.state,
      ready: this.state === "ready" || this.state === "busy",
      busy: Boolean(this.active),
      queued: this.queue.length,
      activeId: this.active?.envelope.id || null,
      pid: this.child?.pid || null,
      cwd: this.cwd,
      command: this.command,
      dangerouslySkipPermissions: this.args.includes("--dangerously-skip-permissions"),
      autoReconnect: this.autoReconnect,
      reconnectAttempt: this.reconnectAttempt,
      reconnectDelay: this.reconnectDelay,
      maxReconnectAttempts: this.reconnectPolicy.maxAttempts,
    };
  }

  async start() {
    if (this.state === "ready" || this.state === "busy") return this.status();
    if (this.startPromise) return this.startPromise;

    this.intentionalStop = false;
    this.clearTimeout(this.reconnectTimer);
    this.reconnectTimer = null;
    this.startupWindow = "";
    this.trustPromptAccepted = false;
    this._setState("connecting");

    this.startPromise = new Promise((resolve, reject) => {
      this.startResolve = resolve;
      this.startReject = reject;
    });
    const pendingStart = this.startPromise;

    try {
      this.child = this.spawnProcess({ command: this.command, args: this.args, cwd: this.cwd });
    } catch (error) {
      this._rejectStart(error);
      this._setState("stopped");
      return pendingStart;
    }

    if (typeof this.child.onData === "function") this.child.onData((data) => this._onOutput(data, "stdout"));
    this.child.stdout?.on("data", (chunk) => this._onOutput(chunk, "stdout"));
    this.child.stderr?.on("data", (chunk) => this._onOutput(chunk, "stderr"));
    this.child.on("error", (error) => this._onProcessError(error));
    if (typeof this.child.onExit === "function") this.child.onExit(({ exitCode, signal }) => this._onExit(exitCode, signal));
    else this.child.on("exit", (code, signal) => this._onExit(code, signal));

    this.startupTimer = this.setTimeout(() => {
      const error = new Error(`Antigravity did not become ready within ${this.startupTimeoutMs}ms`);
      this._rejectStart(error);
      this.emit("fault", { error, phase: "startup" });
      this._killProcessGroup("SIGTERM");
    }, this.startupTimeoutMs);
    this.startupTimer?.unref?.();

    return pendingStart;
  }

  send(prompt, options = {}) {
    return new Promise((resolve, reject) => {
      let envelope;
      try {
        envelope = createEnvelope(prompt, options.id);
      } catch (error) {
        reject(error);
        return;
      }
      const item = {
        prompt,
        envelope,
        timeoutMs: options.timeoutMs || this.responseTimeoutMs,
        resolve,
        reject,
      };
      this.queue.push(item);
      this.emit("queued", { queued: this.queue.length });
      this.start()
        .then(() => this._drain())
        .catch((error) => this._rejectQueue(error));
    });
  }

  cancel(id) {
    if (this.active?.envelope.id === id) return this.interrupt();
    const index = this.queue.findIndex((item) => item.envelope.id === id);
    if (index < 0) return false;
    const [item] = this.queue.splice(index, 1);
    const error = new Error("Antigravity request canceled");
    item.reject(error);
    this.emit("request-error", { id, error });
    this.emit("queued", { queued: this.queue.length });
    return true;
  }

  writeInput(data) {
    if (typeof data !== "string" && !Buffer.isBuffer(data)) {
      return { written: false, reason: "invalid_input" };
    }
    const str = String(data);
    if (str.length === 0) {
      return { written: false, reason: "empty_input" };
    }
    if (Buffer.byteLength(str) > 8192) {
      return { written: false, reason: "exceeds_max_length" };
    }
    if (this.state === "stopped") {
      return { written: false, reason: "session_stopped" };
    }
    // The CLI can show an interactive trust/login/permission prompt while its session is
    // connecting, busy with a prompt, or ready. The terminal must be able to answer those prompts.
    if (!this._canWrite()) {
      return { written: false, reason: "not_writable" };
    }

    try {
      this._write(str);
      return { written: true, bytes: Buffer.byteLength(str) };
    } catch (error) {
      return { written: false, reason: "write_error", error: error.message };
    }
  }

  interrupt() {
    if (!this._canWrite()) return false;
    this._write("\x03");
    if (this.active) {
      this.clearTimeout(this.active.timer);
      clearInterval(this.active.redrawTimer);
      const error = new Error("Antigravity request interrupted");
      this.active.reject(error);
      this.emit("request-error", { id: this.active.envelope.id, error });
      this.active = null;
    }
    this._setState("ready");
    setTimeout(() => this._drain(), 300).unref?.();
    return true;
  }

  async restart() {
    await this.stop({ preserveQueue: true });
    this.intentionalStop = false;
    return this.start();
  }

  async stop(options = {}) {
    this.intentionalStop = true;
    this.clearTimeout(this.reconnectTimer);
    this.clearTimeout(this.startupTimer);
    this.reconnectTimer = null;
    this.startupTimer = null;
    this.reconnectAttempt = 0;
    this.reconnectDelay = 0;
    const error = new Error("Antigravity session stopped");
    this._rejectStart(error);
    if (this.active) {
      this.clearTimeout(this.active.timer);
      clearInterval(this.active.redrawTimer);
      this.active.reject(error);
      this.active = null;
    }
    if (!options.preserveQueue) this._rejectQueue(error);

    const child = this.child;
    if (!child) {
      this._setState("stopped");
      return;
    }

    await new Promise((resolve) => {
      const forceTimer = this.setTimeout(() => {
        this._killProcessGroup("SIGKILL");
        resolve();
      }, 2_000);
      forceTimer?.unref?.();
      child.once("exit", () => {
        this.clearTimeout(forceTimer);
        resolve();
      });
      this._killProcessGroup("SIGTERM");
    });
    this._setState("stopped");
  }

  _onOutput(chunk, stream) {
    const raw = chunk.toString();
    const terminalReply = terminalQueryResponse(raw);
    if (terminalReply && this._canWrite()) this._write(terminalReply);
    const text = stripAnsi(raw);
    this.emit("output", { raw, text, stream });

    if (this.state === "connecting") {
      this.startupWindow = (this.startupWindow + text).slice(-64_000);
      if (
        !this.trustPromptAccepted
        && this.args.includes("--dangerously-skip-permissions")
        && /Do you trust the contents of this project\?/i.test(this.startupWindow)
      ) {
        this.trustPromptAccepted = true;
        this._write("\r");
      }
      if (/Antigravity CLI/i.test(this.startupWindow) && /\? for shortcuts/i.test(this.startupWindow)) {
        this.reconnectAttempt = 0;
        this.reconnectDelay = 0;
        this.clearTimeout(this.startupTimer);
        this.startupTimer = null;
        this._setState("ready");
        this._resolveStart();
        this.emit("connected", this.status());
        this._drain();
      }
    }

    if (!this.active) return;
    this.active.capture = (this.active.capture + text).slice(-4_000_000);
    const beginIndex = this.active.capture.indexOf(this.active.envelope.begin);
    if (beginIndex < 0) return;
    const responseStart = beginIndex + this.active.envelope.begin.length;
    const doneIndex = this.active.capture.indexOf(this.active.envelope.done, responseStart);
    if (doneIndex < 0) return;

    const active = this.active;
    this.active = null;
    this.clearTimeout(active.timer);
    clearInterval(active.redrawTimer);
    const textResult = cleanTranscript(active.capture.slice(responseStart, doneIndex));
    const result = {
      id: active.envelope.id,
      text: textResult,
      durationMs: Date.now() - active.startedAt,
    };
    this._setState("ready");
    active.resolve(result);
    this.emit("response", result);
    setImmediate(() => this._drain());
  }

  _drain() {
    if (this.active || this.state !== "ready" || !this._canWrite()) return;
    const next = this.queue.shift();
    if (!next) return;

    const envelope = next.envelope;

    const timer = this.setTimeout(() => {
      if (!this.active || this.active.envelope.id !== envelope.id) return;
      const active = this.active;
      this.active = null;
      const error = new Error(`Antigravity response timed out after ${next.timeoutMs}ms`);
      clearInterval(active.redrawTimer);
      active.reject(error);
      this.emit("request-error", { id: envelope.id, error });
      this._write("\x03");
      this._setState("ready");
      setTimeout(() => this._drain(), 300).unref?.();
    }, next.timeoutMs);
    timer?.unref?.();

    this.active = { ...next, envelope, capture: "", startedAt: Date.now(), timer, redrawTimer: null };
    this._setState("busy");
    this.emit("request", { id: envelope.id, prompt: next.prompt });
    this._write(`\x1B[200~${envelope.prompt}\x1B[201~\r`);
  }

  _canWrite() {
    return Boolean(typeof this.child?.write === "function" || this.child?.stdin?.writable);
  }

  _write(data) {
    if (typeof this.child?.write === "function") this.child.write(String(data));
    else this.child?.stdin?.write(data);
  }

  resize(cols, rows) {
    const nextCols = Math.max(40, Math.min(240, Number(cols) || 120));
    const nextRows = Math.max(12, Math.min(100, Number(rows) || 40));
    if (typeof this.child?.resize !== "function") return { resized: false, reason: "pty_resize_unavailable" };
    this.child.resize(nextCols, nextRows);
    return { resized: true, cols: nextCols, rows: nextRows };
  }

  _onProcessError(error) {
    this.emit("fault", { error, phase: "process" });
    this._rejectStart(error);
  }

  _onExit(code, signal) {
    this.clearTimeout(this.startupTimer);
    this.startupTimer = null;
    this.child = null;
    const error = new Error(`Antigravity exited (code=${code ?? "none"}, signal=${signal || "none"})`);
    this._rejectStart(error);
    if (this.active) {
      this.clearTimeout(this.active.timer);
      clearInterval(this.active.redrawTimer);
      this.active.reject(error);
      this.emit("request-error", { id: this.active.envelope.id, error });
      this.active = null;
    }
    this.emit("exit", { code, signal, intentional: this.intentionalStop });

    if (!this.intentionalStop && this.autoReconnect) {
      if (this.reconnectAttempt >= this.reconnectPolicy.maxAttempts) {
        const limitError = new Error(`Antigravity reconnect failed after ${this.reconnectAttempt} attempts`);
        this.emit("fault", { error: limitError, phase: "reconnect_limit" });
        this._setState("stopped");
        return;
      }
      this.reconnectAttempt++;
      const delay = this.calculateReconnectDelay(this.reconnectAttempt);
      this.reconnectDelay = delay;
      this._setState("reconnecting");
      this.emit("reconnecting", {
        attempt: this.reconnectAttempt,
        delay,
        maxAttempts: this.reconnectPolicy.maxAttempts,
        nextAttemptAt: Date.now() + delay,
      });

      this.clearTimeout(this.reconnectTimer);
      this.reconnectTimer = this.setTimeout(() => {
        this.reconnectTimer = null;
        if (this.state !== "reconnecting" || this.intentionalStop) return;
        this.start().catch((reconnectError) => this.emit("fault", { error: reconnectError, phase: "reconnect" }));
      }, delay);
      this.reconnectTimer?.unref?.();
    } else {
      this.reconnectAttempt = 0;
      this.reconnectDelay = 0;
      this._setState("stopped");
    }
  }

  _killProcessGroup(signal) {
    const child = this.child;
    if (!child?.pid) return;
    try {
      if (process.platform === "win32") child.kill(signal);
      else process.kill(-child.pid, signal);
    } catch (error) {
      if (error.code !== "ESRCH") this.emit("fault", { error, phase: "shutdown" });
    }
  }

  _setState(state) {
    if (this.state === state) return;
    this.state = state;
    this.emit("state", this.status());
  }

  _resolveStart() {
    const resolve = this.startResolve;
    this.startResolve = null;
    this.startReject = null;
    this.startPromise = null;
    resolve?.(this.status());
  }

  _rejectStart(error) {
    const reject = this.startReject;
    this.startResolve = null;
    this.startReject = null;
    this.startPromise = null;
    reject?.(error);
  }

  _rejectQueue(error) {
    for (const queued of this.queue.splice(0)) queued.reject(error);
  }
}

module.exports = { AgySession, defaultSpawnProcess, resolveAgyCommand, shellQuote, terminalQueryResponse };

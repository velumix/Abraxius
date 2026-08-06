"use strict";

const { EventEmitter } = require("events");
const { spawn } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

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

function resolveOllamaCommand(command) {
  if (command && (command.includes("/") || command.includes("\\"))) {
    const resolved = path.resolve(command);
    if (isExecutable(resolved)) return resolved;
  }

  if (process.env.OLLAMA_COMMAND && isExecutable(process.env.OLLAMA_COMMAND)) {
    return process.env.OLLAMA_COMMAND;
  }

  const binaryName = process.platform === "win32" ? "ollama.exe" : "ollama";

  const userLocalCandidate = path.join(os.homedir(), ".local", "bin", binaryName);
  if (isExecutable(userLocalCandidate)) return userLocalCandidate;

  const pathDirs = (process.env.PATH || "").split(path.delimiter).filter(Boolean);
  for (const dir of pathDirs) {
    const candidate = path.join(dir, binaryName);
    if (isExecutable(candidate)) return candidate;
  }

  const standardCandidates = [
    "/usr/local/bin/" + binaryName,
    "/usr/bin/" + binaryName,
  ];

  for (const candidate of standardCandidates) {
    if (isExecutable(candidate)) return candidate;
  }

  return command || userLocalCandidate;
}

function shellQuote(value) {
  return `'${String(value).replace(/'/g, `'"'"'`)}'`;
}

function defaultSpawnProcess(options) {
  if (process.platform !== "linux") {
    throw new Error("The built-in PTY transport currently requires Linux and util-linux 'script'");
  }
  const executable = [options.command, ...options.args].map(shellQuote).join(" ");
  const command = `stty rows 40 cols 120; exec ${executable}`;
  return spawn("script", ["-qfec", command, "/dev/null"], {
    cwd: options.cwd,
    env: {
      ...process.env,
      TERM: process.env.TERM || "xterm-256color",
      COLUMNS: process.env.COLUMNS || "120",
      LINES: process.env.LINES || "40",
    },
    detached: true,
    stdio: ["pipe", "pipe", "pipe"],
  });
}

class OllamaSession extends EventEmitter {
  constructor(options = {}) {
    super();
    this.command = resolveOllamaCommand(options.command);
    this.model = options.model || "";
    this.args = Array.isArray(options.args)
      ? [...options.args]
      : this.model
      ? ["run", this.model]
      : ["list"];
    this.cwd = options.cwd || process.cwd();
    this.spawnProcess = options.spawnProcess || defaultSpawnProcess;

    this.child = null;
    this.state = "stopped";
    this.startPromise = null;
    this.intentionalStop = false;
  }

  status() {
    return {
      state: this.state,
      ready: this.state === "ready" || this.state === "busy",
      busy: this.state === "busy",
      pid: this.child ? this.child.pid : null,
      model: this.model,
      command: this.command,
      args: this.args,
    };
  }

  async start(options = {}) {
    if (options.model) {
      this.model = options.model;
      this.args = ["run", this.model];
    }
    if (options.command) {
      this.command = resolveOllamaCommand(options.command);
    }
    if (options.args) {
      this.args = [...options.args];
    }

    if (this.child && (this.state === "ready" || this.state === "busy" || this.state === "starting")) {
      return this.status();
    }

    this.state = "starting";
    this.intentionalStop = false;
    this.emit("state", this.status());

    try {
      this.child = this.spawnProcess({
        command: this.command,
        args: this.args,
        cwd: this.cwd,
      });

      this.state = "ready";
      this.emit("connected", this.status());
      this.emit("state", this.status());

      const handleData = (chunk) => {
        const text = chunk.toString("utf8");
        this.emit("output", { data: text, raw: text, pid: this.child ? this.child.pid : null });
      };

      if (this.child.stdout) this.child.stdout.on("data", handleData);
      if (this.child.stderr) this.child.stderr.on("data", handleData);

      this.child.on("exit", (code, signal) => {
        const prevChild = this.child;
        this.child = null;
        this.state = "stopped";
        this.emit("exit", { code, signal, intentional: this.intentionalStop });
        this.emit("state", this.status());
      });

      this.child.on("error", (error) => {
        this.emit("fault", { error: error.message });
      });

      return this.status();
    } catch (error) {
      this.state = "stopped";
      this.child = null;
      this.emit("fault", { error: error.message });
      this.emit("state", this.status());
      throw error;
    }
  }

  writeInput(data) {
    if (typeof data !== "string") {
      return { written: false, reason: "invalid_input" };
    }
    if (!this.child || !this.child.stdin || this.state === "stopped") {
      return { written: false, reason: "session_stopped" };
    }
    try {
      this.child.stdin.write(data);
      return { written: true };
    } catch (error) {
      return { written: false, reason: error.message };
    }
  }

  interrupt() {
    if (!this.child) return false;
    try {
      if (process.platform !== "win32" && this.child.pid) {
        process.kill(-this.child.pid, "SIGINT");
      } else {
        this.child.kill("SIGINT");
      }
      return true;
    } catch {
      try {
        this.child.kill("SIGINT");
        return true;
      } catch {
        return false;
      }
    }
  }

  async stop() {
    this.intentionalStop = true;
    if (!this.child) {
      this.state = "stopped";
      this.emit("state", this.status());
      return this.status();
    }

    const currentChild = this.child;
    return new Promise((resolve) => {
      let resolved = false;
      const done = () => {
        if (resolved) return;
        resolved = true;
        this.child = null;
        this.state = "stopped";
        this.emit("state", this.status());
        resolve(this.status());
      };

      currentChild.once("exit", done);

      try {
        if (process.platform !== "win32" && currentChild.pid) {
          process.kill(-currentChild.pid, "SIGTERM");
        } else {
          currentChild.kill("SIGTERM");
        }
      } catch {
        try { currentChild.kill("SIGTERM"); } catch {}
      }

      setTimeout(() => {
        if (!resolved) {
          try {
            if (process.platform !== "win32" && currentChild.pid) {
              process.kill(-currentChild.pid, "SIGKILL");
            } else {
              currentChild.kill("SIGKILL");
            }
          } catch {}
          done();
        }
      }, 1000);
    });
  }

  async restart(options = {}) {
    await this.stop();
    return this.start(options);
  }
}

module.exports = {
  OllamaSession,
  resolveOllamaCommand,
  defaultSpawnProcess,
};

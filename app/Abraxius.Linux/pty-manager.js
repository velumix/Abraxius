"use strict";

const { EventEmitter } = require("events");
const pty = require("node-pty");
const path = require("path");

class PtyManager extends EventEmitter {
  constructor() {
    super();
    this.sessions = new Map();
    this.activityLog = [];
    this.maxBufferLength = 200000;
    this.maxActivityLogs = 500;
  }

  logActivity(entry) {
    const log = {
      id: `act_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
      timestamp: new Date().toISOString(),
      status: "running",
      ...entry,
    };
    this.activityLog.push(log);
    if (this.activityLog.length > this.maxActivityLogs) {
      this.activityLog.shift();
    }
    this.emit("activity", log);
    return log;
  }

  updateActivity(id, updates) {
    const item = this.activityLog.find((a) => a.id === id);
    if (item) {
      Object.assign(item, updates);
      this.emit("activity-update", item);
    }
  }

  listSessions() {
    const list = [];
    for (const session of this.sessions.values()) {
      list.push({
        id: session.id,
        name: session.name,
        command: session.command,
        args: session.args,
        cwd: session.cwd,
        state: session.state,
        pid: session.pid,
        created: session.created,
        kind: session.kind || "pty",
      });
    }
    return list;
  }

  getSession(id) {
    return this.sessions.get(id);
  }

  getBuffer(id) {
    const session = this.sessions.get(id);
    return session ? session.buffer : "";
  }

  createSession(options = {}) {
    const id = options.id || `pty_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
    if (this.sessions.has(id)) {
      const existing = this.sessions.get(id);
      if (existing.state === "running") {
        return {
          id: existing.id,
          name: existing.name,
          command: existing.command,
          args: existing.args,
          cwd: existing.cwd,
          state: existing.state,
          pid: existing.pid,
          created: existing.created,
          kind: existing.kind || "pty",
        };
      }
      this.sessions.delete(id);
    }

    const defaultShell = process.env.SHELL || (process.platform === "win32" ? "cmd.exe" : "/bin/bash");
    const command = options.command || defaultShell;
    const args = Array.isArray(options.args) ? options.args : [];
    const name = options.name || (options.command ? path.basename(options.command) : "Terminal");
    const cwd = options.cwd || process.cwd();
    const cols = Number(options.cols) || 120;
    const rows = Number(options.rows) || 40;
    const kind = options.kind || "pty";

    const { NO_COLOR, ...inheritedEnv } = process.env;
    const env = {
      ...inheritedEnv,
      TERM: "xterm-256color",
      COLORTERM: "truecolor",
      COLOR: "1",
      CLICOLOR: "1",
      CLICOLOR_FORCE: "1",
      COLUMNS: String(cols),
      LINES: String(rows),
      ...(options.env || {}),
    };

    const sessionObj = {
      id,
      name,
      command,
      args,
      cwd,
      child: null,
      state: "starting",
      buffer: "",
      pid: null,
      created: Date.now(),
      startTime: Date.now(),
      activityId: null,
      kind,
    };

    try {
      const child = pty.spawn(command, args, {
        name: "xterm-256color",
        cols,
        rows,
        cwd,
        env,
      });

      sessionObj.child = child;
      sessionObj.pid = child.pid;
      sessionObj.state = "running";
      this.sessions.set(id, sessionObj);

      const act = this.logActivity({
        sessionId: id,
        sessionName: name,
        command: `${command} ${args.join(" ")}`.trim(),
        status: "running",
      });
      sessionObj.activityId = act.id;

      child.onData((data) => {
        sessionObj.buffer = (sessionObj.buffer + data).slice(-this.maxBufferLength);
        this.emit("event", { id, type: "output", data, pid: child.pid });
      });

      child.onExit(({ exitCode, signal }) => {
        sessionObj.state = "stopped";
        sessionObj.pid = null;
        sessionObj.child = null;
        const durationMs = Date.now() - sessionObj.startTime;
        this.updateActivity(sessionObj.activityId, {
          status: exitCode === 0 ? "success" : "error",
          durationMs,
          exitCode,
        });
        this.emit("event", { id, type: "exit", exitCode, signal, state: "stopped" });
      });

      this.emit("event", { id, type: "state", state: "running", pid: child.pid });
      return {
        id,
        name,
        command,
        args,
        cwd,
        state: "running",
        pid: child.pid,
        created: sessionObj.created,
        kind,
      };
    } catch (error) {
      sessionObj.state = "error";
      this.emit("event", { id, type: "error", error: error.message, state: "error" });
      throw error;
    }
  }

  writeInput(id, data) {
    const session = this.sessions.get(id);
    if (!session || !session.child || session.state !== "running") {
      return { written: false, reason: "session_not_running" };
    }
    try {
      session.child.write(String(data));
      return { written: true };
    } catch (error) {
      return { written: false, reason: error.message };
    }
  }

  resize(id, cols, rows) {
    const session = this.sessions.get(id);
    if (!session || !session.child || session.state !== "running") {
      return { resized: false };
    }
    const nextCols = Math.max(20, Math.min(300, Number(cols) || 120));
    const nextRows = Math.max(5, Math.min(150, Number(rows) || 40));
    try {
      session.child.resize(nextCols, nextRows);
      return { resized: true, cols: nextCols, rows: nextRows };
    } catch (error) {
      return { resized: false, reason: error.message };
    }
  }

  stopSession(id) {
    const session = this.sessions.get(id);
    if (!session) return { stopped: false, reason: "not_found" };

    if (session.child) {
      try {
        session.child.kill("SIGKILL");
      } catch {
        try {
          session.child.kill();
        } catch {}
      }
    }
    session.state = "stopped";
    session.child = null;
    this.emit("event", { id, type: "state", state: "stopped" });
    return { stopped: true };
  }

  restartSession(id) {
    const session = this.sessions.get(id);
    if (!session) return { restarted: false, reason: "not_found" };

    const { name, command, args, cwd, kind } = session;
    this.stopSession(id);
    return this.createSession({ id, name, command, args, cwd, kind });
  }

  closeSession(id) {
    this.stopSession(id);
    this.sessions.delete(id);
    this.emit("event", { id, type: "closed" });
    return { closed: true };
  }
}

module.exports = { PtyManager };

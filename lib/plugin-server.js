const http = require("http");
const { EventEmitter } = require("events");

const DEFAULT_PORT = 13471;
const COMMAND_TIMEOUT_MS = 15000;
const DEFAULT_EVENT_LIMIT = 200;

function sendJson(res, statusCode, obj) {
  res.writeHead(statusCode, { "Content-Type": "application/json" });
  res.end(JSON.stringify(obj));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (err) {
        reject(err);
      }
    });
    req.on("error", reject);
  });
}

function generateId() {
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

class PluginSession {
  constructor(id) {
    this.id = id;
    this.createdAt = Date.now();
    this.lastSeenAt = Date.now();
    this.commandQueue = [];
    this.pendingResponses = new Map();
    this.subscriptions = new Set();
  }

  touch() {
    this.lastSeenAt = Date.now();
  }

  enqueue(command) {
    const id = generateId();
    const cmd = { id, ...command };
    this.commandQueue.push(cmd);
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pendingResponses.delete(id);
        reject(new Error("Plugin command timed out"));
      }, COMMAND_TIMEOUT_MS);
      this.pendingResponses.set(id, { resolve, reject, timer });
    });
  }

  dequeue() {
    const cmds = this.commandQueue;
    this.commandQueue = [];
    return cmds;
  }

  resolveResponse(commandId, result) {
    const pending = this.pendingResponses.get(commandId);
    if (!pending) return false;
    clearTimeout(pending.timer);
    pending.resolve(result);
    this.pendingResponses.delete(commandId);
    return true;
  }

  resolveError(commandId, error) {
    const pending = this.pendingResponses.get(commandId);
    if (!pending) return false;
    clearTimeout(pending.timer);
    pending.reject(new Error(String(error)));
    this.pendingResponses.delete(commandId);
    return true;
  }

  isAlive(timeoutMs = 60000) {
    return Date.now() - this.lastSeenAt < timeoutMs;
  }

  toStatus() {
    return {
      id: this.id,
      createdAt: this.createdAt,
      lastSeenAt: this.lastSeenAt,
      queuedCommands: this.commandQueue.length,
      pendingCommands: this.pendingResponses.size,
      subscriptions: Array.from(this.subscriptions),
      connected: this.isAlive(),
    };
  }
}

class PluginServer extends EventEmitter {
  constructor(options = {}) {
    super();
    this.port = options.port || DEFAULT_PORT;
    this.server = null;
    this.session = null;
    this.commandCounter = 0;
    this.eventLimit = options.eventLimit || DEFAULT_EVENT_LIMIT;
    this.events = [];
    this.nextEventId = 1;
  }

  async start() {
    if (this.server) return;

    this.server = http.createServer(async (req, res) => {
      try {
        const url = new URL(req.url, `http://localhost:${this.port}`);
        const route = `${req.method} ${url.pathname}`;

        switch (route) {
          case "GET /health":
            sendJson(res, 200, {
              running: true,
              connected: this.isConnected(),
              sessionId: this.session?.id || null,
              lastSeenAt: this.session?.lastSeenAt || null,
              queuedEvents: this.events.length,
            });
            break;

          case "POST /plugin/register": {
            const body = await readBody(req);
            const sessionId = body.sessionId || generateId();
            this.session = new PluginSession(sessionId);
            this.emit("connect", this.session);
            sendJson(res, 200, {
              ok: true,
              sessionId,
              pollIntervalMs: 500,
              pollTimeoutMs: 10000,
            });
            break;
          }

          case "POST /plugin/report": {
            const body = await readBody(req);
            if (!this.session || this.session.id !== body.sessionId) {
              sendJson(res, 400, { error: "Invalid or missing session" });
              return;
            }
            this.session.touch();
            if (body.responses) {
              for (const r of body.responses) {
                if (r.error) {
                  this.session.resolveError(r.id, r.error);
                } else {
                  this.session.resolveResponse(r.id, r.result);
                }
              }
            }
            if (body.events) {
              for (const ev of body.events) {
                if (ev && ev.type === "command_responses" && ev.responses) {
                  for (const r of ev.responses) {
                    if (r.error) {
                      this.session.resolveError(r.id, r.error);
                    } else {
                      this.session.resolveResponse(r.id, r.result);
                    }
                  }
                } else {
                  this.recordEvent(ev);
                }
              }
            }
            const commands = this.session.dequeue();
            sendJson(res, 200, { ok: true, commands });
            break;
          }

          case "GET /plugin/status":
            sendJson(res, 200, {
              connected: this.isConnected(),
              sessionId: this.session?.id || null,
              lastSeenAt: this.session?.lastSeenAt || null,
              session: this.session?.toStatus() || null,
              queuedEvents: this.events.length,
              uptime: process.uptime(),
            });
            break;

          case "GET /plugin/events": {
            const limit = Number(url.searchParams.get("limit") || 50);
            const since = Number(url.searchParams.get("since") || 0);
            sendJson(res, 200, {
              events: this.listEvents({ limit, since }),
              nextEventId: this.nextEventId,
            });
            break;
          }

          case "POST /plugin/call": {
            const body = await readBody(req);
            if (!body.command) {
              sendJson(res, 400, { error: "Missing command" });
              return;
            }
            try {
              const result = await this.callPlugin(body.command);
              sendJson(res, 200, { ok: true, result });
            } catch (err) {
              sendJson(res, 500, { error: err.message });
            }
            break;
          }

          default:
            sendJson(res, 404, { error: "Not found" });
        }
      } catch (err) {
        sendJson(res, 500, { error: err.message });
      }
    });

    return new Promise((resolve, reject) => {
      this.server.listen(this.port, () => {
        console.log(`Plugin companion server listening on http://localhost:${this.port}`);
        resolve();
      });
      this.server.on("error", reject);
    });
  }

  stop() {
    if (this.session) {
      for (const pending of this.session.pendingResponses.values()) {
        clearTimeout(pending.timer);
        pending.reject(new Error("Plugin server stopped"));
      }
      this.session = null;
    }
    if (this.server) {
      this.server.close();
      this.server = null;
    }
  }

  isConnected() {
    return !!this.session && this.session.isAlive();
  }

  async callPlugin(command) {
    if (!this.isConnected()) {
      throw new Error("Studio plugin not connected");
    }
    return this.session.enqueue(command);
  }

  recordEvent(event) {
    if (!event || typeof event !== "object") return null;
    const recorded = {
      id: this.nextEventId++,
      time: Date.now(),
      ...event,
    };
    this.events.push(recorded);
    if (this.events.length > this.eventLimit) {
      this.events.splice(0, this.events.length - this.eventLimit);
    }
    this.emit("event", recorded);
    return recorded;
  }

  listEvents(options = {}) {
    const limit = Math.max(1, Math.min(Number(options.limit || 50), this.eventLimit));
    const since = Number(options.since || 0);
    return this.events.filter((ev) => ev.id > since).slice(-limit);
  }
}

module.exports = { PluginServer, PluginSession, DEFAULT_PORT };

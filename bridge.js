const { EventEmitter } = require("events");
const studioLogger = require("./lib/studio-logger");
const WebSocket = require("ws");
const http = require("http");

class RobloxMCPBridge extends EventEmitter {
  constructor(options = {}) {
    super();
    this.port = options.port || 13469;
    this.path = options.path || "/studio";
    this.clientInfo = options.clientInfo || {
      name: "roblox-mcp-bridge",
      version: "1.0.0",
    };
    this.protocolVersion = options.protocolVersion || "2024-11-05";

    this.reconnect = options.reconnect !== false;
    this.reconnectDelayMs = options.reconnectDelayMs || 1000;
    this.maxReconnectDelayMs = options.maxReconnectDelayMs || 30000;
    this.heartbeatIntervalMs = options.heartbeatIntervalMs || 15000;
    this.heartbeatTimeoutMs = options.heartbeatTimeoutMs || 30000;

    this.server = null;
    this.ws = null;
    this.nextId = 0;
    this.pending = new Map();
    this.ready = false;
    this.serverInfo = null;
    this.tools = [];

    this._reconnectTimer = null;
    this._currentReconnectDelay = this.reconnectDelayMs;
    this._heartbeatTimer = null;
    this._heartbeatTimeout = null;
    this._shutdown = false;
  }

  async start(timeoutMs = 30000) {
    if (this.server) throw new Error("Bridge already started");

    await new Promise((resolve, reject) => {
      this.server = http.createServer();
      const wss = new WebSocket.Server({
        server: this.server,
        path: this.path,
      });

      wss.on("connection", (ws, req) => {
        if (this.ws) {
          console.warn(
            "[bridge] Roblox Studio tried to connect but a connection already exists",
          );
          ws.close(1008, "Only one Studio connection allowed");
          return;
        }
        this._onConnection(ws, req);
      });

      this.server.on("error", reject);
      this.server.listen(this.port, () => {
        this.emit("listening", { port: this.port, path: this.path });
        resolve();
      });
    });

    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(
          new Error(
            `Roblox Studio did not connect within ${timeoutMs}ms. Make sure Studio is open and MCP is enabled.`,
          ),
        );
      }, timeoutMs);

      const onReady = () => {
        clearTimeout(timer);
        this.off("error", onError);
        resolve(this.serverInfo);
      };
      const onError = (err) => {
        clearTimeout(timer);
        this.off("ready", onReady);
        reject(err);
      };
      this.once("ready", onReady);
      this.once("error", onError);
    });
  }

  stop() {
    this._shutdown = true;
    this.ready = false;
    this._clearReconnect();
    this._clearHeartbeat();
    if (this.ws) {
      try {
        this.ws.close();
      } catch {}
      this.ws = null;
    }
    for (const [id, { reject }] of this.pending) {
      reject(new Error("Bridge stopped"));
    }
    this.pending.clear();
    if (this.server) {
      try {
        this.server.close();
      } catch {}
      this.server = null;
    }
  }

  _onConnection(ws, req) {
    this._clearReconnect();
    this._currentReconnectDelay = this.reconnectDelayMs;
    this.ws = ws;
    this.emit("connection", req.connection.remoteAddress);

    ws.on("message", (data) => this._onMessage(data));
    ws.on("pong", () => this._handlePong());
    ws.on("close", (code, reason) => {
      this.ready = false;
      this.ws = null;
      this.serverInfo = null;
      this.tools = [];
      this._clearHeartbeat();
      for (const [id, { reject }] of this.pending) {
        reject(new Error("Roblox Studio disconnected"));
      }
      this.pending.clear();
      this.emit("disconnect", code, reason?.toString());
      this._scheduleReconnect();
    });
    ws.on("error", (err) => this.emit("error", err));

    this._request("initialize", {
      protocolVersion: this.protocolVersion,
      capabilities: { roots: { listChanged: true } },
      clientInfo: this.clientInfo,
    })
      .then((result) => {
        this.serverInfo = result;
        this._notify("notifications/initialized", {});
        this.ready = true;
        this.emit("ready", result);
        this._startHeartbeat();
        this.logToStudio("connect", "Bridge connected");
      })
      .catch((err) => this.emit("error", err));
  }

  _onMessage(data) {
    let text;
    try {
      text = data.toString("utf8");
    } catch (err) {
      this.emit("parseError", err);
      return;
    }

    let msg;
    try {
      msg = JSON.parse(text);
    } catch (err) {
      this.emit("parseError", err, text);
      return;
    }

    this.emit("message", msg);

    if (msg.type && msg.type !== "json_rpc") {
      this.emit("unknownType", msg);
      return;
    }

    if (msg.id !== undefined) {
      const pending = this.pending.get(msg.id);
      if (pending) {
        this.pending.delete(msg.id);
        if (msg.error) {
          const err = new Error(msg.error.message || "MCP error");
          err.code = msg.error.code;
          err.data = msg.error.data;
          pending.reject(err);
        } else {
          pending.resolve(msg.result);
        }
        return;
      }
      if (msg.method) {
        this._handleRequest(msg.id, msg.method, msg.params);
        return;
      }
    } else if (msg.method) {
      this.emit("notification", msg.method, msg.params);
    }
  }

  _handleRequest(id, method, params) {
    if (method === "ping") {
      this._send({ jsonrpc: "2.0", id, result: {} });
      return;
    }
    this.emit("request", id, method, params);
  }

  _send(obj) {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error("WebSocket not connected");
    }
    const envelope = { type: "json_rpc", ...obj };
    this.ws.send(JSON.stringify(envelope));
    this.emit("send", envelope);
  }

  _request(method, params = {}) {
    const id = `${method}-${++this.nextId}-${cryptoRandomUUID()}`;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      try {
        this._send({ jsonrpc: "2.0", id, method, params });
      } catch (err) {
        this.pending.delete(id);
        reject(err);
      }
    });
  }

  _notify(method, params = {}) {
    this._send({ jsonrpc: "2.0", method, params });
  }

  _startHeartbeat() {
    this._clearHeartbeat();
    if (this.heartbeatIntervalMs <= 0) return;
    this._heartbeatTimer = setInterval(() => {
      if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
        this._clearHeartbeat();
        return;
      }
      try {
        this.ws.ping();
        this._heartbeatTimeout = setTimeout(() => {
          this.emit("error", new Error("Heartbeat timeout; reconnecting"));
          this.ws.terminate();
        }, this.heartbeatTimeoutMs);
      } catch {
        this._clearHeartbeat();
      }
    }, this.heartbeatIntervalMs);
  }

  _handlePong() {
    if (this._heartbeatTimeout) {
      clearTimeout(this._heartbeatTimeout);
      this._heartbeatTimeout = null;
    }
  }

  _clearHeartbeat() {
    if (this._heartbeatTimer) {
      clearInterval(this._heartbeatTimer);
      this._heartbeatTimer = null;
    }
    if (this._heartbeatTimeout) {
      clearTimeout(this._heartbeatTimeout);
      this._heartbeatTimeout = null;
    }
  }

  _scheduleReconnect() {
    if (!this.reconnect || this._shutdown) return;
    this._clearReconnect();
    this._reconnectTimer = setTimeout(() => {
      this.emit("reconnecting", this._currentReconnectDelay);
      this._currentReconnectDelay = Math.min(
        this._currentReconnectDelay * 2,
        this.maxReconnectDelayMs,
      );
    }, this._currentReconnectDelay);
  }

  _clearReconnect() {
    if (this._reconnectTimer) {
      clearTimeout(this._reconnectTimer);
      this._reconnectTimer = null;
    }
  }

  async listTools() {
    const result = await this._request("tools/list", {});
    this.tools = result.tools || [];
    return this.tools;
  }

  async callTool(name, args = {}) {
    if (name !== "execute_luau") {
      this.logToStudio("studio", `Tool call: ${name}`);
    }
    return this._request("tools/call", { name, arguments: args });
  }

  async logToStudio(levelOrMessage, message) {
    if (!this.ready) return;
    const level = message ? levelOrMessage : "info";
    const text = message || levelOrMessage;
    const formatted = studioLogger.format(level, text);
    const escaped = String(formatted)
      .replace(/\r\n|\r|\n/g, " ")
      .replace(/["\\]/g, "\\$&");
    try {
      await this._request("tools/call", {
        name: "execute_luau",
        arguments: {
          code: `print("${escaped}")`,
          datamodel_type: "Edit",
        },
      });
    } catch {
      // Silent fail - Studio output is optional.
    }
  }

  async listPrompts() {
    const result = await this._request("prompts/list", {});
    return result.prompts || [];
  }

  async getPrompt(name, args = {}) {
    return this._request("prompts/get", { name, arguments: args });
  }

  async listResources() {
    const result = await this._request("resources/list", {});
    return result.resources || [];
  }

  async readResource(uri) {
    return this._request("resources/read", { uri });
  }

  async getStudioState() {
    return this.callTool("get_studio_state", {});
  }

  async executeLuau(code, datamodelType = "Workspace") {
    this.logToStudio("studio", "Executing Luau");
    return this.callTool("execute_luau", {
      code,
      datamodel_type: datamodelType,
    });
  }

  async listRobloxStudios() {
    return this.callTool("list_roblox_studios", {});
  }

  async setActiveStudio(studioId) {
    return this.callTool("set_active_studio", { studio_id: studioId });
  }
}

function cryptoRandomUUID() {
  if (typeof crypto !== "undefined" && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    return (c === "x" ? r : (r & 0x3) | 0x8).toString(16);
  });
}

module.exports = { RobloxMCPBridge };

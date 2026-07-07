const http = require("http");
const { API_PORT } = require("./server");

function request(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: "localhost",
      port: API_PORT,
      path,
      method,
      headers: { "Content-Type": "application/json" },
    };

    const req = http.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        try {
          const contentType = res.headers["content-type"] || "";
          const obj = contentType.includes("application/json")
            ? JSON.parse(data)
            : data;
          if (res.statusCode >= 400) {
            const err = new Error(
              typeof obj === "object" && obj.error ? obj.error : `HTTP ${res.statusCode}`,
            );
            err.statusCode = res.statusCode;
            err.body = obj;
            reject(err);
          } else {
            resolve(obj);
          }
        } catch (err) {
          reject(err);
        }
      });
    });

    req.on("error", (err) => {
      err.message = `Cannot connect to MCP daemon on localhost:${API_PORT}. Is it running? (${err.message})`;
      reject(err);
    });

    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

function withQuery(path, query = {}) {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query)) {
    if (value !== undefined && value !== null) {
      params.set(key, String(value));
    }
  }
  const qs = params.toString();
  return qs ? `${path}?${qs}` : path;
}

class MCPClient {
  async health() {
    return request("GET", "/health");
  }

  async tools() {
    return request("GET", "/tools");
  }

  async call(name, args = {}) {
    return request("POST", "/call", { name, arguments: args });
  }

  async smartCall(name, args = {}) {
    return request("POST", "/smart-call", { name, arguments: args });
  }

  async state() {
    return request("GET", "/state");
  }

  async execute(code, datamodelType) {
    return request("POST", "/execute", {
      code,
      datamodel_type: datamodelType,
    });
  }

  async context(snapshot) {
    if (snapshot) {
      return request("POST", "/context", snapshot);
    }
    return request("GET", "/context");
  }

  async setContext(ctx) {
    return request("POST", "/context", ctx);
  }

  async aiContext(options = {}) {
    return request("GET", withQuery("/ai-context", options));
  }

  async memory(options = {}) {
    return request("GET", withQuery("/memory", options));
  }

  async remember(text, options = {}) {
    return request("POST", "/memory", { text, ...options });
  }

  async clearMemory(options = {}) {
    return request("POST", "/memory/clear", options);
  }

  async editScript(filePath, edits) {
    return request("POST", "/edit-script", { file_path: filePath, edits });
  }

  async batch(calls, mode = "sequential") {
    return request("POST", "/batch", { calls, mode });
  }

  async findReplace(paths, oldString, newString) {
    return request("POST", "/find-replace", {
      paths,
      old_string: oldString,
      new_string: newString,
    });
  }

  async searchScripts(options = {}) {
    return request("POST", "/search-scripts", options);
  }

  async shutdown() {
    return request("POST", "/shutdown");
  }

  async pending() {
    return request("GET", "/pending");
  }

  async pendingVerify() {
    return request("POST", "/pending/verify", {});
  }

  async pendingClear(path) {
    return request("POST", "/pending/clear", path ? { path } : {});
  }

  async pluginStatus() {
    return request("GET", "/plugin/status");
  }

  async pluginEvents(options = {}) {
    return request("GET", withQuery("/plugin/events", options));
  }

  async pluginCall(command) {
    return request("POST", "/plugin/call", { command });
  }

  async log(message) {
    return request("POST", "/log", { message });
  }
}

module.exports = { MCPClient, request };

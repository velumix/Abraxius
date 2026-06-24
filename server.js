const http = require("http");
const { spawn } = require("child_process");
const path = require("path");
const fs = require("fs");
const os = require("os");
const { RobloxMCPBridge } = require("./bridge");

const API_PORT = 13470;
const PID_FILE = path.join(os.tmpdir(), "abraxius.pid");
const LOG_FILE = path.join(os.tmpdir(), "abraxius.log");

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

async function createServer(bridge) {
  const server = http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url, `http://localhost:${API_PORT}`);
      const route = `${req.method} ${url.pathname}`;
      if (
        bridge.ready &&
        url.pathname !== "/health" &&
        url.pathname !== "/log"
      ) {
        bridge.logToStudio(`[Abraxius] HTTP ${route}`);
      }

      switch (route) {
        case "GET /health":
          sendJson(res, 200, {
            running: true,
            connected: bridge.ready,
            studio: bridge.serverInfo?.serverInfo || null,
            toolsLoaded: bridge.tools.length,
          });
          break;

        case "GET /tools": {
          const tools = bridge.ready ? await bridge.listTools() : [];
          sendJson(res, 200, { tools });
          break;
        }

        case "POST /call": {
          if (!bridge.ready) {
            sendJson(res, 503, { error: "Roblox Studio not connected" });
            return;
          }
          const body = await readBody(req);
          const { name, arguments: args = {} } = body;
          if (!name) {
            sendJson(res, 400, { error: "Missing 'name' field" });
            return;
          }
          const result = await bridge.callTool(name, args);
          bridge.logToStudio(`[Abraxius] HTTP /call: ${name}`);
          sendJson(res, 200, result);
          break;
        }

        case "GET /state": {
          if (!bridge.ready) {
            sendJson(res, 503, { error: "Roblox Studio not connected" });
            return;
          }
          const result = await bridge.getStudioState();
          sendJson(res, 200, result);
          break;
        }

        case "POST /execute": {
          if (!bridge.ready) {
            sendJson(res, 503, { error: "Roblox Studio not connected" });
            return;
          }
          const body = await readBody(req);
          const { code, datamodel_type = "Edit" } = body;
          if (!code) {
            sendJson(res, 400, { error: "Missing 'code' field" });
            return;
          }
          const result = await bridge.executeLuau(code, datamodel_type);
          sendJson(res, 200, result);
          break;
        }

        case "POST /log": {
          if (!bridge.ready) {
            sendJson(res, 503, { error: "Roblox Studio not connected" });
            return;
          }
          const body = await readBody(req);
          const { message } = body;
          if (!message) {
            sendJson(res, 400, { error: "Missing 'message' field" });
            return;
          }
          bridge.logToStudio(message);
          sendJson(res, 200, { ok: true });
          break;
        }

        case "POST /shutdown":
          sendJson(res, 200, { status: "shutting down" });
          setTimeout(() => process.exit(0), 100);
          break;

        default:
          sendJson(res, 404, { error: "Not found" });
      }
    } catch (err) {
      sendJson(res, 500, { error: err.message });
    }
  });

  return new Promise((resolve) => {
    server.listen(API_PORT, () => {
      console.log(`MCP API server listening on http://localhost:${API_PORT}`);
      resolve(server);
    });
  });
}

async function runDaemon() {
  const bridge = new RobloxMCPBridge();

  bridge.on("listening", () =>
    console.log("Waiting for Roblox Studio on ws://localhost:13469/studio"),
  );
  bridge.on("connection", (addr) =>
    console.log(`Roblox Studio connected from ${addr}`),
  );
  bridge.on("ready", () => console.log("Studio ready"));
  bridge.on("disconnect", () => console.log("Roblox Studio disconnected"));
  bridge.on("error", (err) => console.error("[bridge error]", err.message));

  await bridge.start();
  await createServer(bridge);
}

function startBackground() {
  if (fs.existsSync(PID_FILE)) {
    const pid = fs.readFileSync(PID_FILE, "utf8").trim();
    try {
      process.kill(Number(pid), 0);
      console.log(`Daemon already running (PID ${pid})`);
      return;
    } catch {
      fs.unlinkSync(PID_FILE);
    }
  }

  const log = fs.openSync(LOG_FILE, "a");
  const proc = spawn(process.execPath, [__filename, "--daemon"], {
    detached: true,
    stdio: ["ignore", log, log],
    windowsHide: true,
  });
  proc.unref();

  fs.writeFileSync(PID_FILE, String(proc.pid));
  console.log(`Daemon started (PID ${proc.pid})`);
}

function stopBackground() {
  if (!fs.existsSync(PID_FILE)) {
    console.log("Daemon not running");
    return;
  }
  const pid = Number(fs.readFileSync(PID_FILE, "utf8").trim());
  try {
    process.kill(pid, "SIGTERM");
    console.log(`Daemon stopped (PID ${pid})`);
  } catch (err) {
    console.error("Failed to stop daemon:", err.message);
  }
  try {
    fs.unlinkSync(PID_FILE);
  } catch {}
}

function isRunning() {
  if (!fs.existsSync(PID_FILE)) return false;
  const pid = Number(fs.readFileSync(PID_FILE, "utf8").trim());
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    try {
      fs.unlinkSync(PID_FILE);
    } catch {}
    return false;
  }
}

// CLI for daemon management (used by `node server.js start|stop|status`)
if (require.main === module) {
  const command = process.argv[2];
  if (command === "start") {
    startBackground();
  } else if (command === "stop") {
    stopBackground();
  } else if (command === "status") {
    console.log(isRunning() ? "Daemon is running" : "Daemon is not running");
  } else if (command === "--daemon") {
    runDaemon().catch((err) => {
      console.error("Daemon failed:", err);
      process.exit(1);
    });
  } else {
    // Default: run in foreground
    runDaemon().catch((err) => {
      console.error("Server failed:", err);
      process.exit(1);
    });
  }
}

module.exports = {
  API_PORT,
  PID_FILE,
  LOG_FILE,
  createServer,
  isRunning,
};

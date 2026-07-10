const http = require("http");
const { spawn } = require("child_process");
const path = require("path");
const fs = require("fs");
const os = require("os");
const { RobloxMCPBridge } = require("./bridge");
const { MCPContext } = require("./lib/context");
const { PendingPushes } = require("./lib/pending");
const logger = require("./lib/logger");
const { PluginServer } = require("./lib/plugin-server");
const {
  addMemory,
  buildAiContext,
  clearMemory,
  loadMemory,
  toMarkdown,
} = require("./lib/ai-context");

const API_PORT = 13470;
const PLUGIN_PORT = 13471;
const PID_FILE = path.join(os.tmpdir(), "abraxius.pid");
const LOG_FILE = path.join(os.tmpdir(), "abraxius.log");

const context = new MCPContext();
const pendingPushes = new PendingPushes();
const pluginServer = new PluginServer({ port: PLUGIN_PORT });

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

async function ensureConnected(bridge) {
  if (!bridge.ready) {
    throw new Error("Roblox Studio not connected");
  }
}

async function runWithStateCache(bridge, fn) {
  const state = await fn();
  context.setStudioState(state);
  return state;
}

async function createServer(bridge) {
  const server = http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url, `http://localhost:${API_PORT}`);
      const route = `${req.method} ${url.pathname}`;
      if (
        bridge.ready &&
        url.pathname !== "/health" &&
        url.pathname !== "/log" &&
        url.pathname !== "/context"
      ) {
        logger.http(req.method, url.pathname);
        bridge.logToStudio("http", `${req.method} ${url.pathname}`);
      }

      switch (route) {
        case "GET /health":
          sendJson(res, 200, {
            running: true,
            connected: bridge.ready,
            studio: bridge.serverInfo?.serverInfo || null,
            toolsLoaded: bridge.tools.length,
            pluginConnected: pluginServer.isConnected(),
            pluginEvents: pluginServer.events.length,
            uptime: process.uptime(),
          });
          break;

        case "GET /tools": {
          const tools = bridge.ready ? await bridge.listTools() : [];
          sendJson(res, 200, { tools });
          break;
        }

        case "POST /call": {
          await ensureConnected(bridge);
          const body = await readBody(req);
          const { name, arguments: args = {} } = body;
          if (!name) {
            sendJson(res, 400, { error: "Missing 'name' field" });
            return;
          }
          const result = await bridge.callTool(name, args);
          logger.cli(name);
          bridge.logToStudio("studio", `Tool call: ${name}`);
          try {
            if (name === "multi_edit" && args.file_path && args.edits && args.edits[0]) {
              pendingPushes.recordPush(args.file_path, args.edits[0].new_string);
            }
          } catch {}
          sendJson(res, 200, result);
          break;
        }

        case "GET /state": {
          await ensureConnected(bridge);
          const result = await runWithStateCache(bridge, () =>
            bridge.getStudioState(),
          );
          sendJson(res, 200, result);
          break;
        }

        case "POST /execute": {
          await ensureConnected(bridge);
          const body = await readBody(req);
          const { code, datamodel_type } = body;
          if (!code) {
            sendJson(res, 400, { error: "Missing 'code' field" });
            return;
          }
          const dm = context.resolveDatamodel(datamodel_type);
          const result = await bridge.executeLuau(code, dm);
          context.record({
            type: "execute",
            datamodel: dm,
            summary: code.slice(0, 80),
          });
          sendJson(res, 200, result);
          break;
        }

        case "POST /log": {
          await ensureConnected(bridge);
          const body = await readBody(req);
          const { message } = body;
          if (!message) {
            sendJson(res, 400, { error: "Missing 'message' field" });
            return;
          }
          bridge.logToStudio("studio", message);
          sendJson(res, 200, { ok: true });
          break;
        }

        case "GET /context":
          sendJson(res, 200, context.toSnapshot());
          break;

        case "POST /context": {
          const body = await readBody(req);
          if (body.projectDir) context.setProjectDir(body.projectDir);
          if (body.datamodel) context.preferredDatamodel = body.datamodel;
          sendJson(res, 200, context.toSnapshot());
          break;
        }

        case "GET /ai-context": {
          const format = url.searchParams.get("format") || "json";
          const projectDir = url.searchParams.get("projectDir") || context.projectDir;
          const snapshot = buildAiContext({
            context,
            pendingPushes,
            pluginServer,
            projectDir,
          });
          if (format === "markdown" || format === "md") {
            res.writeHead(200, { "Content-Type": "text/markdown" });
            res.end(toMarkdown(snapshot));
          } else {
            sendJson(res, 200, snapshot);
          }
          break;
        }

        case "GET /memory": {
          const projectDir = url.searchParams.get("projectDir") || context.projectDir;
          sendJson(res, 200, {
            projectDir: projectDir || process.cwd(),
            memory: loadMemory(projectDir || undefined),
          });
          break;
        }

        case "POST /memory": {
          const body = await readBody(req);
          const projectDir = body.projectDir || context.projectDir;
          const { memory, entry } = addMemory(projectDir || undefined, {
            text: body.text,
            tags: body.tags,
            path: body.path,
            source: body.source || "user",
          });
          sendJson(res, 200, {
            ok: true,
            projectDir: projectDir || process.cwd(),
            entry,
            memory,
          });
          break;
        }

        case "POST /memory/clear": {
          const body = await readBody(req);
          const projectDir = body.projectDir || context.projectDir;
          sendJson(res, 200, {
            ok: true,
            projectDir: projectDir || process.cwd(),
            memory: clearMemory(projectDir || undefined, body.id),
          });
          break;
        }

        case "POST /smart-call": {
          await ensureConnected(bridge);
          const body = await readBody(req);
          const { name, arguments: args = {} } = body;
          if (!name) {
            sendJson(res, 400, { error: "Missing 'name' field" });
            return;
          }

          const normalized = { ...args };
          if (
            normalized.datamodel_type === undefined &&
            name === "execute_luau"
          ) {
            normalized.datamodel_type = context.resolveDatamodel();
          }
          if (
            normalized.datamodel_type === undefined &&
            name === "multi_edit"
          ) {
            normalized.datamodel_type = "Edit";
          }

          const result = await bridge.callTool(name, normalized);
          context.record({
            type: "call",
            target: normalized.file_path || normalized.target_file || name,
            datamodel: normalized.datamodel_type || context.preferredDatamodel,
            summary: name,
          });

          if (name === "get_studio_state") {
            context.setStudioState(result);
          }
          if (name === "script_read" && normalized.target_file) {
            context.touchScript(context.normalizePath(normalized.target_file));
          }
          if (name === "multi_edit" && normalized.file_path) {
            context.touchScript(context.normalizePath(normalized.file_path));
            context.invalidate("tree:");
            try {
              const pushedSource = normalized.edits && normalized.edits[0] && normalized.edits[0].new_string;
              if (typeof pushedSource === "string") {
                pendingPushes.recordPush(normalized.file_path, pushedSource);
              }
            } catch {}
          }

          sendJson(res, 200, result);
          break;
        }

        case "POST /edit-script": {
          await ensureConnected(bridge);
          const body = await readBody(req);
          const { file_path, edits = [] } = body;
          if (!file_path || !Array.isArray(edits) || edits.length === 0) {
            sendJson(res, 400, { error: "Missing file_path or edits" });
            return;
          }
          const studioPath = context.normalizePath(file_path);

          const readResult = await bridge.callTool("script_read", {
            target_file: studioPath,
            should_read_entire_file: true,
          });
          context.touchScript(studioPath);

          const result = await bridge.callTool("multi_edit", {
            file_path: studioPath,
            datamodel_type: "Edit",
            edits,
          });

          context.touchScript(studioPath);
          context.record({
            type: "edit",
            target: studioPath,
            datamodel: "Edit",
            summary: `${edits.length} edit(s)`,
          });
          context.invalidate("tree:");
          try {
            const pushedSource = edits[0] && edits[0].new_string;
            if (typeof pushedSource === "string") {
              pendingPushes.recordPush(studioPath, pushedSource);
            }
          } catch {}

          sendJson(res, 200, { readResult, editResult: result });
          break;
        }

        case "POST /batch": {
          await ensureConnected(bridge);
          const body = await readBody(req);
          const { calls = [], mode = "sequential" } = body;
          if (!Array.isArray(calls) || calls.length === 0) {
            sendJson(res, 400, { error: "Missing calls array" });
            return;
          }

          const results = [];
          if (mode === "parallel") {
            const tasks = calls.map((call, index) =>
              bridge
                .callTool(call.name, call.arguments || {})
                .then((result) => ({ index, ok: true, result }))
                .catch((err) => ({ index, ok: false, error: err.message })),
            );
            const settled = await Promise.all(tasks);
            results.push(...settled);
          } else {
            for (let i = 0; i < calls.length; i++) {
              try {
                const result = await bridge.callTool(
                  calls[i].name,
                  calls[i].arguments || {},
                );
                results.push({ index: i, ok: true, result });
              } catch (err) {
                results.push({ index: i, ok: false, error: err.message });
              }
            }
          }
          sendJson(res, 200, { results });
          break;
        }

        case "POST /find-replace": {
          await ensureConnected(bridge);
          const body = await readBody(req);
          const { paths = [], old_string, new_string } = body;
          if (!old_string || paths.length === 0) {
            sendJson(res, 400, { error: "Missing paths or old_string" });
            return;
          }

          const results = [];
          for (const p of paths) {
            const studioPath = context.normalizePath(p);
            try {
              const result = await bridge.callTool("multi_edit", {
                file_path: studioPath,
                datamodel_type: "Edit",
                edits: [{ old_string, new_string }],
              });
              context.touchScript(studioPath);
              context.record({
                type: "edit",
                target: studioPath,
                datamodel: "Edit",
                summary: "find-replace",
              });
              results.push({ path: studioPath, ok: true, result });
            } catch (err) {
              results.push({ path: studioPath, ok: false, error: err.message });
            }
          }
          context.invalidate("tree:");
          sendJson(res, 200, { results });
          break;
        }

        case "POST /search-scripts": {
          await ensureConnected(bridge);
          const body = await readBody(req);
          const {
            keywords,
            query,
            path = "ServerScriptService",
            instance_type = "BaseScript",
            max_depth = 10,
            head_limit = 200,
          } = body;

          const cacheKey = `tree:${path}:${instance_type}:${keywords || ""}:${query || ""}`;
          const cached = context.getCache(cacheKey);
          if (cached) {
            sendJson(res, 200, cached);
            return;
          }

          let result;
          if (query) {
            result = await bridge.callTool("script_grep", { query });
          } else {
            result = await bridge.callTool("search_game_tree", {
              path,
              instance_type,
              max_depth,
              head_limit,
              keywords: keywords || undefined,
            });
          }

          context.setCache(cacheKey, result);
          sendJson(res, 200, result);
          break;
        }

        case "GET /pending":
          sendJson(res, 200, { pushes: pendingPushes.list() });
          break;

        case "POST /pending/verify": {
          const pushes = pendingPushes.list().filter((p) => p.status !== "committed");
          const verified = [];
          for (const push of pushes) {
            try {
              if (!pluginServer.isConnected()) {
                pendingPushes.setError(push.path, "Studio plugin not connected");
                verified.push(pendingPushes.get(push.path));
                continue;
              }
              const result = await pluginServer.callPlugin({
                type: "read_source",
                path: push.path,
              });
              const source = result && result.source;
              verified.push(pendingPushes.verify(push.path, source));
            } catch (err) {
              verified.push(pendingPushes.setError(push.path, err.message));
            }
          }
          sendJson(res, 200, { verified });
          break;
        }

        case "POST /pending/clear": {
          const body = await readBody(req);
          if (body.path) {
            pendingPushes.clear(body.path);
          } else {
            pendingPushes.clear();
          }
          sendJson(res, 200, { ok: true, pushes: pendingPushes.list() });
          break;
        }

        case "GET /plugin/status":
          sendJson(res, 200, {
            connected: pluginServer.isConnected(),
            sessionId: pluginServer.session?.id || null,
            lastSeenAt: pluginServer.session?.lastSeenAt || null,
            session: pluginServer.session?.toStatus() || null,
            queuedEvents: pluginServer.events.length,
          });
          break;

        case "GET /plugin/events": {
          const limit = Number(url.searchParams.get("limit") || 50);
          const since = Number(url.searchParams.get("since") || 0);
          sendJson(res, 200, {
            events: pluginServer.listEvents({ limit, since }),
            nextEventId: pluginServer.nextEventId,
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
            const result = await pluginServer.callPlugin(body.command);
            sendJson(res, 200, { ok: true, result });
          } catch (err) {
            sendJson(res, 500, { error: err.message });
          }
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
      logger.success(`MCP API server listening on http://localhost:${API_PORT}`);
      resolve(server);
    });
  });
}

async function runDaemon() {
  logger.startupBanner("matrix");
  const bridge = new RobloxMCPBridge();

  bridge.on("listening", () =>
    logger.info("Waiting for Roblox Studio on ws://localhost:13469/studio"),
  );
  bridge.on("connection", (addr) =>
    logger.success(`Roblox Studio connected from ${addr}`),
  );
  bridge.on("ready", () => logger.success("🎮 Studio ready"));
  bridge.on("disconnect", () => logger.warn("Roblox Studio disconnected"));
  bridge.on("reconnecting", (delay) =>
    logger.info(`Waiting for Studio reconnect in ${delay}ms`),
  );
  bridge.on("error", (err) => logger.error(`bridge error: ${err.message}`));

  // All local endpoints must remain available while Studio connects or
  // reconnects. Studio readiness is connection state, not daemon readiness.
  await Promise.all([
    bridge.start(),
    createServer(bridge),
    pluginServer.start(),
  ]);

  pluginServer.on("connect", async () => {
    try {
      const pushes = pendingPushes.list().filter((p) => p.status !== "committed");
      for (const push of pushes) {
        const result = await pluginServer.callPlugin({ type: "read_source", path: push.path });
        pendingPushes.verify(push.path, result && result.source);
      }
    } catch {}
  });

  pluginServer.on("event", async (ev) => {
    context.ingestStudioEvent(ev);
    if (ev && ev.type === "source_changed" && pendingPushes.get(ev.path)) {
      try {
        const result = await pluginServer.callPlugin({ type: "read_source", path: ev.path });
        pendingPushes.verify(ev.path, result && result.source);
      } catch {}
    }
  });

}

function startBackground() {
  if (fs.existsSync(PID_FILE)) {
    const pid = fs.readFileSync(PID_FILE, "utf8").trim();
    try {
      process.kill(Number(pid), 0);
      logger.warn(`Daemon already running (PID ${pid})`);
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
  logger.startupBanner("matrix"); logger.success(`Daemon started (PID ${proc.pid})`);
}

function stopBackground() {
  if (!fs.existsSync(PID_FILE)) {
    logger.warn("Daemon not running");
    return;
  }
  const pid = Number(fs.readFileSync(PID_FILE, "utf8").trim());
  try {
    process.kill(pid, "SIGTERM");
    logger.success(`Daemon stopped (PID ${pid})`);
  } catch (err) {
    logger.error(`Failed to stop daemon: ${err.message}`);
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

if (require.main === module) {
  const command = process.argv[2];
  if (command === "start") {
    startBackground();
  } else if (command === "stop") {
    stopBackground();
  } else if (command === "status") {
    logger.info(isRunning() ? "Daemon is running" : "Daemon is not running");
  } else if (command === "--daemon") {
    runDaemon().catch((err) => {
      logger.error(`Daemon failed: ${err.message}`);
      process.exit(1);
    });
  } else {
    runDaemon().catch((err) => {
      logger.error(`Server failed: ${err.message}`);
      process.exit(1);
    });
  }
}

module.exports = {
  API_PORT,
  PLUGIN_PORT,
  PID_FILE,
  LOG_FILE,
  createServer,
  isRunning,
  context,
  pendingPushes,
  pluginServer,
};

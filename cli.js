#!/usr/bin/env node
const { spawn } = require("child_process");
const path = require("path");
const fs = require("fs");
const { MCPClient } = require("./client");
const logger = require("./lib/logger");
const { isRunning, PID_FILE, API_PORT } = require("./server");
const { Puller } = require("./lib/pull");
const { Pusher } = require("./lib/push");
const {
  addMemory,
  buildAiContext,
  clearMemory,
  loadMemory,
  toMarkdown,
} = require("./lib/ai-context");

const USAGE = `
Usage: mcp <command> [args]

Daemon:
  start                 Start the MCP bridge daemon in the background
  stop                  Stop the daemon
  status                Check if the daemon is running
  logs                  Tail the daemon log file

Queries:
  tools                 List available Roblox Studio tools
  state                 Get current studio state
  call <name> [json]    Call a tool, e.g.:
                          mcp call get_studio_state
                          mcp call search_game_tree '{"path":"Workspace","max_depth":2}'
                          mcp call multi_edit '{"file_path":"...","edits":[...]}'
  smart <name> [json]   Context-aware tool call (auto datamodel, records history)
  execute <code>        Execute Luau code, e.g.:
                          mcp execute 'print(game.Workspace)'
  repl                  Interactive tool-calling REPL

Context:
  context               Show session context (recent scripts, datamodel, project)
  context project <dir> Set active project directory
  context datamodel <dm> Set preferred datamodel (Edit/Client/Server)
  ai-context [--json] [--project <dir>]
                        Print one AI-readable briefing with memory + live context
  remember <text> [--tag <tag>] [--path <path>] [--project <dir>]
                        Pin a durable project fact for future AI sessions
  memory                List pinned project memory
  memory clear [id]     Clear all memory, or one memory entry by id

High-level edits:
  edit <path> <old> <new>
                        Read + edit a script in one step
  batch <file>          Run a JSON batch file of tool calls
  find-replace <paths-file> <old> <new>
                        Find/replace across multiple Studio scripts
  search [keywords]     Smart script search (default: ServerScriptService BaseScript)

Plugin:
  plugin                Show Studio plugin connection status
  plugin events [limit] Show recent Studio companion events
  plugin selection      Show current Studio Explorer selection
  plugin state          Show plugin-observed Studio state
  plugin call <type> [json]
                        Send a raw command to the Studio companion plugin
  pending               List pending pushes (Draft Mode tracking)
  pending verify        Ask the plugin which pushes are still stale
  pending clear [path]  Clear pending push record(s)

Sync:
  pull [dir]            Pull all scripts from Studio into a local project.
                        Defaults to current directory. Creates src/ and place.json.
  pull --target <path> [dir]
                        Pull one Studio script, e.g.:
                          mcp pull --target ServerScriptService.MatchManager
  pull --targets-file <file> [dir]
                        Pull a list of Studio paths from a file (one per line).
  push <file>           Push a local script file back to Studio using multi_edit.
                        Requires the file to be inside a place.json project.
`;

function findProjectDir(startPath) {
  let dir = path.resolve(path.dirname(startPath));
  const root = path.parse(dir).root;
  while (dir !== root) {
    if (fs.existsSync(path.join(dir, "place.json"))) return dir;
    dir = path.dirname(dir);
  }
  return fs.existsSync(path.join(dir, "place.json")) ? dir : null;
}

function parseJson(str) {
  if (!str) return {};
  try {
    return JSON.parse(str);
  } catch (err) {
    throw new Error(`Invalid JSON: ${err.message}`);
  }
}

function parseOptions(argv) {
  const out = { _: [], tags: [] };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--project") {
      out.projectDir = argv[++i];
    } else if (arg === "--tag") {
      out.tags.push(argv[++i]);
    } else if (arg === "--path") {
      out.path = argv[++i];
    } else if (arg === "--json") {
      out.json = true;
    } else {
      out._.push(arg);
    }
  }
  return out;
}

function ensureDaemon() {
  if (isRunning()) return;
  logger.startupBanner("matrix");
  logger.info("Starting MCP daemon...");
  const log = fs.openSync(
    path.join(require("os").tmpdir(), "abraxius.log"),
    "a",
  );
  const proc = spawn(
    process.execPath,
    [path.join(__dirname, "server.js"), "--daemon"],
    {
      detached: true,
      stdio: ["ignore", log, log],
      windowsHide: true,
    },
  );
  proc.unref();
  fs.writeFileSync(PID_FILE, String(proc.pid));
}

async function waitForReady(timeoutMs = 20000) {
  const client = new MCPClient();
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const health = await client.health();
      if (health.connected) return health;
    } catch {}
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error(
    `Daemon did not become ready within ${timeoutMs}ms. Check logs with: mcp logs`,
  );
}

async function withClient(fn) {
  if (!isRunning()) {
    ensureDaemon();
  }
  const health = await waitForReady();
  if (!health.connected) {
    throw new Error(
      "Daemon is running but Roblox Studio is not connected. Open Studio and enable MCP.",
    );
  }
  const client = new MCPClient();
  return fn(client);
}

async function main() {
  const [, , command, ...args] = process.argv;

  try {
    switch (command) {
      case "start":
        if (isRunning()) {
          logger.warn("Daemon already running");
        } else {
          ensureDaemon();
          const health = await waitForReady();
          logger.success("Daemon started and connected"); logger.studio(JSON.stringify(health.studio));
        }
        break;

      case "stop": {
        if (!isRunning()) {
          logger.warn("Daemon not running");
          return;
        }
        const client = new MCPClient();
        await client.shutdown();
        logger.success("Daemon stopped");
        break;
      }

      case "status": {
        const running = isRunning();
        logger.info(running ? "Daemon is running" : "Daemon is not running");
        if (running) {
          try {
            const client = new MCPClient();
            const health = await client.health();
            logger.info(`Studio connected: ${health.connected}`);
            if (health.studio) logger.studio(JSON.stringify(health.studio));
            logger.info(`Uptime: ${health.uptime} s`);
            const ctx = await client.context();
            console.log("Context:", JSON.stringify(ctx, null, 2));
          } catch (err) {
            console.error("Could not query daemon:", err.message);
          }
        }
        break;
      }

      case "logs": {
        const logPath = path.join(require("os").tmpdir(), "abraxius.log");
        if (!fs.existsSync(logPath)) {
          console.log("No log file yet");
          return;
        }
        fs.createReadStream(logPath).pipe(process.stdout);
        break;
      }

      case "tools": {
        const result = await withClient(async (c) => {
          logger.cli("tools"); await c.log("🧰 tools");
          return c.tools();
        });
        console.log(JSON.stringify(result.tools, null, 2));
        break;
      }

      case "state": {
        const result = await withClient(async (c) => {
          logger.cli("state"); await c.log("📊 state");
          return c.state();
        });
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case "call": {
        const [name, json] = args;
        if (!name) throw new Error("Tool name required");
        const result = await withClient(async (c) => {
          logger.cli("call", name); await c.log(`⚡ call ${name}`);
          return c.call(name, parseJson(json));
        });
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case "smart": {
        const [name, json] = args;
        if (!name) throw new Error("Tool name required");
        const result = await withClient(async (c) => {
          logger.cli("smart", name); await c.log(`🧠 smart ${name}`);
          return c.smartCall(name, parseJson(json));
        });
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case "execute": {
        const code = args.join(" ");
        if (!code) throw new Error("Luau code required");
        const result = await withClient(async (c) => {
          logger.cli("execute"); await c.log("▶️ execute");
          return c.execute(code);
        });
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case "context": {
        const [sub, value] = args;
        const client = new MCPClient();
        if (sub === "project") {
          const snapshot = await client.setContext({
            projectDir: value || ".",
          });
          console.log(JSON.stringify(snapshot, null, 2));
        } else if (sub === "datamodel") {
          const snapshot = await client.setContext({
            datamodel: value || "Edit",
          });
          console.log(JSON.stringify(snapshot, null, 2));
        } else {
          const snapshot = await client.context();
          console.log(JSON.stringify(snapshot, null, 2));
        }
        break;
      }

      case "ai-context": {
        const opts = parseOptions(args);
        const projectDir = opts.projectDir || process.cwd();
        if (isRunning()) {
          try {
            const client = new MCPClient();
            const result = await client.aiContext({
              projectDir,
              format: opts.json ? "json" : "markdown",
            });
            console.log(typeof result === "string" ? result : JSON.stringify(result, null, 2));
            break;
          } catch {}
        }
        const snapshot = buildAiContext({ projectDir });
        console.log(opts.json ? JSON.stringify(snapshot, null, 2) : toMarkdown(snapshot));
        break;
      }

      case "remember": {
        const opts = parseOptions(args);
        const text = opts._.join(" ");
        if (!text) throw new Error('Usage: mcp remember "durable project fact"');
        const projectDir = opts.projectDir || process.cwd();
        const { entry } = addMemory(projectDir, {
          text,
          tags: opts.tags,
          path: opts.path,
          source: "user",
        });
        console.log(JSON.stringify({ ok: true, projectDir, entry }, null, 2));
        break;
      }

      case "memory": {
        const [sub] = args;
        const opts = parseOptions(sub === "clear" ? args.slice(1) : args);
        const projectDir = opts.projectDir || process.cwd();
        if (sub === "clear") {
          const memory = clearMemory(projectDir, opts._[0] || null);
          console.log(JSON.stringify({ ok: true, projectDir, memory }, null, 2));
        } else {
          console.log(JSON.stringify({ projectDir, memory: loadMemory(projectDir) }, null, 2));
        }
        break;
      }

      case "edit": {
        const [filePath, oldString, newString] = args;
        if (!filePath || oldString === undefined || newString === undefined) {
          throw new Error("Usage: mcp edit <path> <old> <new>");
        }
        const result = await withClient(async (c) => {
          logger.cli("edit", filePath); await c.log(`✏️ edit ${filePath}`);
          return c.editScript(filePath, [
            { old_string: oldString, new_string: newString },
          ]);
        });
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case "batch": {
        const file = args[0];
        if (!file || !fs.existsSync(file)) {
          throw new Error("Batch JSON file required");
        }
        const { calls, mode } = parseJson(fs.readFileSync(file, "utf8"));
        const result = await withClient(async (c) => {
          logger.cli("batch"); await c.log("📦 batch");
          return c.batch(calls, mode);
        });
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case "find-replace": {
        const [pathsFile, oldString, newString] = args;
        if (
          !pathsFile ||
          !fs.existsSync(pathsFile) ||
          oldString === undefined
        ) {
          throw new Error("Usage: mcp find-replace <paths-file> <old> <new>");
        }
        const paths = fs
          .readFileSync(pathsFile, "utf8")
          .split("\n")
          .map((l) => l.trim())
          .filter(Boolean);
        const result = await withClient(async (c) => {
          logger.cli("find-replace"); await c.log("🔁 find-replace");
          return c.findReplace(paths, oldString, newString || "");
        });
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case "search": {
        const keywords = args.join(" ");
        const result = await withClient(async (c) => {
          logger.cli("search"); await c.log("🔍 search");
          return c.searchScripts(
            keywords
              ? {
                  keywords,
                  path: "ServerScriptService",
                  instance_type: "BaseScript",
                }
              : { path: "ServerScriptService", instance_type: "BaseScript" },
          );
        });
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case "repl":
        await repl();
        break;

      case "pull": {
        const targets = [];
        let outputDir = ".";
        for (let i = 0; i < args.length; i++) {
          const arg = args[i];
          if (arg === "--target" || arg === "-t") {
            const target = args[++i];
            if (!target) throw new Error("Missing target after --target");
            targets.push(target);
          } else if (arg === "--targets-file") {
            const file = args[++i];
            if (!file || !fs.existsSync(file))
              throw new Error(`Missing or invalid targets file: ${file}`);
            const list = fs
              .readFileSync(file, "utf8")
              .split("\n")
              .map((l) => l.trim())
              .filter(Boolean);
            targets.push(...list);
          } else if (!arg.startsWith("-")) {
            outputDir = arg;
          }
        }

        await withClient(async (client) => {
          logger.cli("pull", outputDir); await client.log(`📥 pull -> ${outputDir}`);
          const puller = new Puller(client, {
            outputDir,
            targets: targets.length > 0 ? targets : undefined,
            concurrency: 4,
            delayMs: 50,
            onProgress: (action, target) =>
              console.log(`[${action}] ${target}`),
          });
          const { project, stats } = await puller.pull();
          console.log("\nProject:", JSON.stringify(project.tree, null, 2));
          console.log("Stats:", stats);
        });
        break;
      }

      case "push": {
        const file = args[0];
        if (!file) throw new Error("File path required");
        const projectDir = findProjectDir(file);
        if (!projectDir)
          throw new Error(`Could not find place.json for ${file}`);
        await withClient(async (client) => {
          const pusher = new Pusher(client, { projectDir });
          const { changed, studioPath, result } = await pusher.push(file);
          if (!changed) {
            console.log(`No changes for ${studioPath}`);
          } else {
            console.log(`Pushed ${file} -> ${studioPath}`);
            console.log(JSON.stringify(result, null, 2));
          }
          logger.cli("push", `${file} -> ${studioPath}`); await client.log(`🚀 push ${file}`);
        });
        break;
      }


      case "plugin": {
        const [sub, ...pluginArgs] = args;
        const result = await withClient(async (c) => {
          if (!sub || sub === "status") {
            return c.pluginStatus();
          }
          if (sub === "events") {
            const limit = pluginArgs[0] ? Number(pluginArgs[0]) : 50;
            return c.pluginEvents({ limit });
          }
          if (sub === "selection") {
            return c.pluginCall({ type: "get_selection" });
          }
          if (sub === "state") {
            return c.pluginCall({ type: "get_state" });
          }
          if (sub === "call") {
            const [type, json] = pluginArgs;
            if (!type) throw new Error("Usage: mcp plugin call <type> [json]");
            return c.pluginCall({ type, ...parseJson(json) });
          }
          throw new Error(
            "Usage: mcp plugin [status|events|selection|state|call]",
          );
        });
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case "pending": {
        const sub = args[0];
        if (sub === "verify") {
          const result = await withClient(async (c) => c.pendingVerify());
          console.log(JSON.stringify(result, null, 2));
        } else if (sub === "clear") {
          const pathArg = args[1];
          const result = await withClient(async (c) => c.pendingClear(pathArg));
          console.log(JSON.stringify(result, null, 2));
        } else {
          const result = await withClient(async (c) => c.pending());
          console.log(JSON.stringify(result, null, 2));
        }
        break;
      }

      default:
        console.log(USAGE);
        process.exit(command ? 1 : 0);
    }
  } catch (err) {
    console.error("Error:", err.message);
    process.exit(1);
  }
}

async function repl() {
  const readline = require("readline");
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  await withClient(async (client) => {
    const tools = (await client.tools()).tools;
    console.log(
      "\nConnected. Available tools:",
      tools.map((t) => t.name).join(", "),
    );
    console.log("Type: <tool-name> <json-args>");
    console.log("      smart <tool-name> <json-args>");
    console.log("      state");
    console.log("      context");
    console.log("      execute <luau-code>");
    console.log("      exit\n");

    const ask = (q) => new Promise((resolve) => rl.question(q, resolve));

    while (true) {
      const line = await ask("mcp> ");
      const trimmed = line.trim();
      if (!trimmed) continue;
      if (trimmed === "exit" || trimmed === "quit") break;

      try {
        if (trimmed === "state") {
          logger.cli("repl state"); await client.log("📊 repl state");
          console.log(JSON.stringify(await client.state(), null, 2));
          continue;
        }
        if (trimmed === "context") {
          console.log(JSON.stringify(await client.context(), null, 2));
          continue;
        }
        if (trimmed.startsWith("execute ")) {
          const code = trimmed.slice(8);
          logger.cli("repl execute"); await client.log("▶️ repl execute");
          console.log(JSON.stringify(await client.execute(code), null, 2));
          continue;
        }

        const useSmart = trimmed.startsWith("smart ");
        const rest = useSmart ? trimmed.slice(6) : trimmed;
        const parts = rest.split(/\s+/);
        const [name, ...jsonParts] = parts;
        const json = jsonParts.join(" ");
        await client.log(
          `🎮 repl ${useSmart ? "smart" : "call"}: ${name}`,
        );
        console.log(
          JSON.stringify(
            useSmart
              ? await client.smartCall(name, parseJson(json))
              : await client.call(name, parseJson(json)),
            null,
            2,
          ),
        );
      } catch (err) {
        console.error("Error:", err.message);
      }
    }
  });

  rl.close();
}

main();

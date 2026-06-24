#!/usr/bin/env node
const { spawn } = require("child_process");
const path = require("path");
const fs = require("fs");
const { MCPClient } = require("./client");
const { isRunning, PID_FILE, API_PORT } = require("./server");
const { Puller } = require("./lib/pull");
const { Pusher } = require("./lib/push");

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
  execute <code>        Execute Luau code, e.g.:
                          mcp execute 'print(game.Workspace)'
  repl                  Interactive tool-calling REPL

Sync:
  pull [dir]            Pull scripts from Studio into a local project.
                        Defaults to current directory. Creates src/ and place.json.
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

function ensureDaemon() {
  if (isRunning()) return;
  console.log("Starting MCP daemon...");
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
          console.log("Daemon already running");
        } else {
          ensureDaemon();
          const health = await waitForReady();
          console.log("Daemon started and connected:", health.studio);
        }
        break;

      case "stop": {
        if (!isRunning()) {
          console.log("Daemon not running");
          return;
        }
        const client = new MCPClient();
        await client.shutdown();
        console.log("Daemon stopped");
        break;
      }

      case "status": {
        const running = isRunning();
        console.log(running ? "Daemon is running" : "Daemon is not running");
        if (running) {
          try {
            const client = new MCPClient();
            const health = await client.health();
            console.log("Studio connected:", health.connected);
            if (health.studio) console.log("Studio:", health.studio);
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
          await c.log("[Abraxius] CLI tools");
          return c.tools();
        });
        console.log(JSON.stringify(result.tools, null, 2));
        break;
      }

      case "state": {
        const result = await withClient(async (c) => {
          await c.log("[Abraxius] CLI state");
          return c.state();
        });
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case "call": {
        const [name, json] = args;
        if (!name) throw new Error("Tool name required");
        const result = await withClient(async (c) => {
          await c.log(`[Abraxius] CLI call: ${name}`);
          return c.call(name, parseJson(json));
        });
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case "execute": {
        const code = args.join(" ");
        if (!code) throw new Error("Luau code required");
        const result = await withClient(async (c) => {
          await c.log("[Abraxius] CLI execute");
          return c.execute(code);
        });
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case "repl":
        await repl();
        break;

      case "pull": {
        const outputDir = args[0] || ".";
        await withClient(async (client) => {
          await client.log(`[Abraxius] CLI pull -> ${outputDir}`);
          const puller = new Puller(client, {
            outputDir,
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
          await client.log(`[Abraxius] CLI push: ${file} -> ${studioPath}`);
        });
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
    console.log("      state");
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
          await client.log("[Abraxius] CLI repl state");
          console.log(JSON.stringify(await client.state(), null, 2));
          continue;
        }
        if (trimmed.startsWith("execute ")) {
          const code = trimmed.slice(8);
          await client.log("[Abraxius] CLI repl execute");
          console.log(JSON.stringify(await client.execute(code), null, 2));
          continue;
        }
        const parts = trimmed.split(/\s+/);
        const [name, ...jsonParts] = parts;
        const json = jsonParts.join(" ");
        await client.log(`[Abraxius] CLI repl call: ${name}`);
        console.log(
          JSON.stringify(await client.call(name, parseJson(json)), null, 2),
        );
      } catch (err) {
        console.error("Error:", err.message);
      }
    }
  });

  rl.close();
}

main();

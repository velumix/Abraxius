#!/usr/bin/env node
const path = require("path");
const fs = require("fs");
const { spawn } = require("node:child_process");
const { MCPClient } = require("./client");
const logger = require("./lib/logger");
const { Puller } = require("./lib/pull");
const { Pusher } = require("./lib/push");
const { encodeAxlError, executePluginAxl, parseAxl } = require("./lib/axl");
const { readJsonObjectArgument, readTextArgument } = require("./lib/cli-input");
const {
  addMemory,
  buildAiContext,
  clearMemory,
  loadMemory,
  toMarkdown,
} = require("./lib/ai-context");
const {
  fetchGitHubContext,
  toGitHubMarkdown,
} = require("./lib/github-context");
const { ABRAXIUS_NOTICE, getHumanNotice } = require("./lib/mcp-notice");
const { runMcpStdioServer } = require("./lib/mcp-server");
const { OpenRouterClient, DEFAULT_MODEL: DEFAULT_OPENROUTER_MODEL } = require("./lib/openrouter");
const { NvidiaNimClient, DEFAULT_MODEL: DEFAULT_NVIDIA_NIM_MODEL } = require("./lib/nvidia-nim");
const { getNimBridgeInfo } = require("./lib/nvidia-nim-bridge");

const studioEmoji = {
  tools: String.fromCodePoint(0x1f9f0),
  state: String.fromCodePoint(0x1f4ca),
  call: String.fromCodePoint(0x26a1),
  smart: String.fromCodePoint(0x1f9e0),
  execute: String.fromCodePoint(0x25b6, 0xfe0f),
  edit: String.fromCodePoint(0x270f, 0xfe0f),
  batch: String.fromCodePoint(0x1f4e6),
  replace: String.fromCodePoint(0x1f501),
  search: String.fromCodePoint(0x1f50d),
  pull: String.fromCodePoint(0x1f4e5),
  push: String.fromCodePoint(0x1f680),
  repl: String.fromCodePoint(0x1f3ae),
};

const studioLog = (icon, message) => `${icon} ${message}`;

const USAGE = `
Usage: mcp <command> [args]

App host & MCP server:
  stdio                 Start stdio MCP server for generic LLM CLIs
  openrouter <prompt>   Send a prompt through OpenRouter (uses OPENROUTER_API_KEY)
  nim <prompt>          Stream a prompt through NVIDIA NIM (uses NVIDIA_NIM_API_KEY)
  nvidia-nim <prompt>   Alias for nim
  discovery             Print machine-readable capability manifest & notice
  start                 Confirm the Abraxius App host is running
  stop                  Explain how to stop the host from the app
  status                Check the app-supervised host and Studio connections
  logs                  Tail the app-supervised host log

Queries:
  axl <command>         Run one AXL/1 command. Supports --file, --stdin, or
                        --ast for parser/debug JSON without execution.
  tools                 List available Roblox Studio tools
  state                 Get current studio state
  call <name> [json]    Call a tool. JSON can also use --json-file or --json-stdin.
                          mcp call get_studio_state
                          mcp call search_game_tree '{"path":"Workspace","max_depth":2}'
                          mcp call multi_edit '{"file_path":"...","edits":[...]}'
  smart <name> [json]   Context-aware tool call (auto datamodel, records history)
  execute <code>        Execute Luau code. Also supports --file or --stdin, e.g.:
                          mcp execute 'print(game.Workspace)'
  repl                  Interactive tool-calling REPL

Context:
  context               Show session context (recent scripts, datamodel, project)
  context project <dir> Set active project directory
  context datamodel <dm> Set preferred datamodel (Edit/Client/Server)
  ai-context [--json] [--project <dir>]
                        Print one AI-readable briefing with Studio + GitHub context
  github-context [owner/repo] [--json] [--project <dir>]
                        Read repository, PR, release, and Actions context from
                        the GitHub REST API. Uses GITHUB_TOKEN or GH_TOKEN when set.
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
  plugin inspect <path> List an instance's direct children
  plugin select <paths> Select one or more Studio instances
  plugin open <path> [line]
                        Open a Studio script at a line
  plugin call <type> [json|--json-file <file>|--json-stdin]
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
  push <file>           Push a local script or .rbxm/.rbxmx model to Studio.
                        Uses the companion when MCP is offline. Requires the
                        file to be inside a place.json project.
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
      const val = argv[++i];
      if (val !== undefined) out.projectDir = val;
      else throw new Error("Missing value after --project");
    } else if (arg === "--tag") {
      const val = argv[++i];
      if (val !== undefined) out.tags.push(val);
      else throw new Error("Missing value after --tag");
    } else if (arg === "--path") {
      const val = argv[++i];
      if (val !== undefined) out.path = val;
      else throw new Error("Missing value after --path");
    } else if (arg === "--json") {
      out.json = true;
    } else if (arg.startsWith("--")) {
      throw new Error(`Unknown option: ${arg}`);
    } else {
      out._.push(arg);
    }
  }
  return out;
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

async function probeDaemon() {
  try {
    const health = await new MCPClient().health();
    return health.running ? health : null;
  } catch {
    return null;
  }
}

async function withClient(fn) {
  if (!(await probeDaemon())) {
    throw new Error(
      "Abraxius App host is offline. Launch Abraxius from Windows; the CLI does not start a separate daemon.",
    );
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

async function withDaemonClient(fn) {
  if (!(await probeDaemon())) {
    throw new Error(
      "Abraxius App host is offline. Launch Abraxius from Windows; the CLI does not start a separate daemon.",
    );
  }
  return fn(new MCPClient());
}

function tryRunNvidiaNimViaAppBridge(prompt) {
  return new Promise((resolve, reject) => {
    const userDataDir = path.join(require("os").homedir(), ".config", "Abraxius");
    const info = getNimBridgeInfo(userDataDir);
    if (!info || !info.port || !info.token) return resolve(false);

    const http = require("http");
    const healthReq = http.request(
      `http://127.0.0.1:${info.port}/health`,
      { method: "GET", headers: { Authorization: `Bearer ${info.token}` }, timeout: 1000 },
      (res) => {
        if (res.statusCode !== 200) return resolve(false);
        let body = "";
        res.on("data", (chunk) => { body += chunk; });
        res.on("end", () => {
          let data;
          try { data = JSON.parse(body); } catch { return resolve(false); }
          if (!data || data.hasApiKey !== true) return resolve(false);

          const req = http.request(
            `http://127.0.0.1:${info.port}/v1/nim/chat`,
            {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${info.token}`,
              },
            },
            (streamRes) => {
              if (streamRes.statusCode !== 200) {
                let errBody = "";
                streamRes.on("data", (c) => { errBody += c; });
                streamRes.on("end", () => reject(new Error(`NVIDIA NIM app bridge returned HTTP ${streamRes.statusCode}: ${errBody}`)));
                return;
              }

              let buffer = "";
              let eventName = "";

              const onSigInt = () => {
                req.destroy();
                reject(new Error("NVIDIA NIM prompt cancelled by user."));
              };
              process.once("SIGINT", onSigInt);

              streamRes.on("data", (chunk) => {
                buffer += chunk.toString("utf8");
                const lines = buffer.split(/\r?\n/);
                buffer = lines.pop() || "";

                for (const line of lines) {
                  const trimmed = line.trim();
                  if (!trimmed) continue;
                  if (trimmed.startsWith("event:")) {
                    eventName = trimmed.slice(6).trim();
                  } else if (trimmed.startsWith("data:")) {
                    let payload;
                    try { payload = JSON.parse(trimmed.slice(5).trim()); } catch {}
                    if ((eventName === "reasoning" || eventName === "chunk") && payload?.chunk) {
                      process.stdout.write(payload.chunk);
                    } else if (eventName === "error" && payload?.error) {
                      process.removeListener("SIGINT", onSigInt);
                      return reject(new Error(payload.error));
                    }
                  }
                }
              });

              streamRes.on("end", () => {
                process.removeListener("SIGINT", onSigInt);
                process.stdout.write("\n");
                resolve(true);
              });
              streamRes.on("error", (err) => {
                process.removeListener("SIGINT", onSigInt);
                reject(err);
              });
            },
          );

          req.on("error", () => resolve(false));
          req.write(JSON.stringify({ prompt }));
          req.end();
        });
      },
    );

    healthReq.on("error", () => resolve(false));
    healthReq.on("timeout", () => { healthReq.destroy(); resolve(false); });
    healthReq.end();
  });
}

function runNvidiaNimWithSavedAppKey(prompt) {
  return new Promise((resolve, reject) => {
    const electronPath = process.env.ELECTRON_BIN || path.join(__dirname, "node_modules", "electron", "dist", "electron");
    if (!fs.existsSync(electronPath)) return reject(new Error("Electron runtime not found. Set ELECTRON_BIN or configure NVIDIA_NIM_API_KEY."));
    const { ELECTRON_RUN_AS_NODE, ...helperEnv } = process.env;
    const child = spawn(electronPath, [path.join(__dirname, "scripts", "nvidia-nim-app-key.js"), prompt], { env: helperEnv, stdio: ["ignore", "inherit", "inherit"] });
    child.once("error", reject);
    child.once("exit", (code) => code === 0 ? resolve() : reject(new Error(`NVIDIA NIM helper exited with code ${code}`)));
  });
}

async function main() {
  const [, , command, ...args] = process.argv;

  try {
    switch (command) {
      case "stdio":
      case "serve":
      case "mcp-server":
      case "serve-mcp":
        runMcpStdioServer();
        break;

      case "discovery":
      case "discover":
      case "manifest":
      case "info": {
        const output = {
          abraxius: ABRAXIUS_NOTICE,
          notice: getHumanNotice(),
        };
        console.log(JSON.stringify(output, null, 2));
        break;
      }

      case "openrouter": {
        const prompt = args.join(" ").trim();
        if (!prompt) throw new Error("Usage: mcp openrouter <prompt>");
        if (!process.env.OPENROUTER_API_KEY) {
          throw new Error("OPENROUTER_API_KEY is not configured. Set it in the Abraxius process environment; the key is never printed or persisted.");
        }
        const model = process.env.OPENROUTER_MODEL || DEFAULT_OPENROUTER_MODEL;
        const client = new OpenRouterClient({
          apiKey: process.env.OPENROUTER_API_KEY,
          endpoint: process.env.OPENROUTER_ENDPOINT,
        });
        await client.streamChat({
          model,
          messages: [{ role: "user", content: prompt }],
          onChunk: (chunk) => process.stdout.write(chunk),
        });
        process.stdout.write("\n");
        break;
      }

      case "nim":
      case "nvidia-nim": {
        const prompt = args.join(" ").trim();
        if (!prompt) throw new Error("Usage: mcp nim <prompt>");
        if (!process.env.NVIDIA_NIM_API_KEY) {
          const bridged = await tryRunNvidiaNimViaAppBridge(prompt);
          if (bridged) break;
          await runNvidiaNimWithSavedAppKey(prompt);
          break;
        }
        const client = new NvidiaNimClient({
          apiKey: process.env.NVIDIA_NIM_API_KEY,
          endpoint: process.env.NVIDIA_NIM_ENDPOINT,
          model: process.env.NVIDIA_NIM_MODEL || DEFAULT_NVIDIA_NIM_MODEL,
          temperature: process.env.NVIDIA_NIM_TEMPERATURE,
          topP: process.env.NVIDIA_NIM_TOP_P,
          maxTokens: process.env.NVIDIA_NIM_MAX_TOKENS,
          reasoningBudget: process.env.NVIDIA_NIM_REASONING_BUDGET,
        });
        await client.streamChat({
          messages: [{ role: "user", content: prompt }],
          onReasoning: (chunk) => process.stdout.write(chunk),
          onChunk: (chunk) => process.stdout.write(chunk),
        });
        process.stdout.write("\n");
        break;
      }

      case "start":
        if (await probeDaemon()) logger.success("Abraxius App host is running");
        else throw new Error("Launch Abraxius from Windows. Host lifecycle belongs to the app.");
        break;

      case "stop": {
        throw new Error(
          "Stop or quit Abraxius from its window or tray menu. The CLI cannot stop the app-owned host.",
        );
        break;
      }

      case "status": {
        logger.info(getHumanNotice());
        const health = await probeDaemon();
        const running = !!health;
        logger.info(running ? "Daemon is running" : "Daemon is not running");
        if (running) {
          try {
            const client = new MCPClient();
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
        const nativeLog = process.env.LOCALAPPDATA
          ? path.join(process.env.LOCALAPPDATA, "Abraxius", "abraxius-host.log")
          : null;
        const nodeLog = path.join(require("os").tmpdir(), "abraxius.log");
        const logPath = nativeLog && fs.existsSync(nativeLog) ? nativeLog : nodeLog;
        if (!fs.existsSync(logPath)) {
          console.log("No log file yet");
          return;
        }
        fs.createReadStream(logPath).pipe(process.stdout);
        break;
      }

      case "tools": {
        const result = await withClient(async (c) => {
          logger.cli("tools"); await c.log(studioLog(studioEmoji.tools, "List tools"));
          return c.tools();
        });
        console.log(JSON.stringify(result.tools, null, 2));
        break;
      }

      case "state": {
        const result = await withClient(async (c) => {
          logger.cli("state"); await c.log(studioLog(studioEmoji.state, "Read Studio state"));
          return c.state();
        });
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case "call": {
        const [name, ...inputArgs] = args;
        if (!name) throw new Error("Tool name required");
        const toolArguments = await readJsonObjectArgument(inputArgs);
        const result = await withClient(async (c) => {
          logger.cli("call", name); await c.log(studioLog(studioEmoji.call, `Call ${name}`));
          return c.call(name, toolArguments);
        });
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case "smart": {
        const [name, ...inputArgs] = args;
        if (!name) throw new Error("Tool name required");
        const toolArguments = await readJsonObjectArgument(inputArgs);
        const result = await withClient(async (c) => {
          logger.cli("smart", name); await c.log(studioLog(studioEmoji.smart, `Smart call ${name}`));
          return c.smartCall(name, toolArguments);
        });
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case "execute": {
        const code = await readTextArgument(args);
        const result = await withClient(async (c) => {
          logger.cli("execute"); await c.log(studioLog(studioEmoji.execute, "Execute Luau"));
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
        let github = null;
        try {
          github = await fetchGitHubContext({ projectDir });
        } catch {}
        if (await probeDaemon()) {
          try {
            const client = new MCPClient();
            const result = await client.aiContext({
              projectDir,
              format: opts.json ? "json" : "markdown",
            });
            if (typeof result === "string") {
              console.log(
                github
                  ? `${result.trimEnd()}\n\n${toGitHubMarkdown(github)}`
                  : result,
              );
            } else {
              if (github) result.github = github;
              console.log(JSON.stringify(result, null, 2));
            }
            break;
          } catch {}
        }
        const snapshot = buildAiContext({ projectDir });
        if (github) snapshot.github = github;
        console.log(opts.json ? JSON.stringify(snapshot, null, 2) : toMarkdown(snapshot));
        break;
      }

      case "github":
      case "github-context": {
        const opts = parseOptions(args);
        const projectDir = opts.projectDir || process.cwd();
        const github = await fetchGitHubContext({
          projectDir,
          repository: opts._[0],
        });
        console.log(
          opts.json
            ? JSON.stringify(github, null, 2)
            : toGitHubMarkdown(github),
        );
        break;
      }

      case "axl": {
        const astOnly = args.includes("--ast");
        const inputArgs = args.filter((arg) => arg !== "--ast");
        const source = await readTextArgument(inputArgs);
        let ast;
        try {
          ast = parseAxl(source);
        } catch (error) {
          console.error(encodeAxlError(error));
          process.exitCode = 1;
          break;
        }
        if (astOnly) {
          console.log(JSON.stringify(ast, null, 2));
          break;
        }
        try {
          const response = await withDaemonClient((client) => executePluginAxl(source, client));
          console.log(response);
        } catch (error) {
          console.error(encodeAxlError(error));
          process.exitCode = 1;
        }
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
          logger.cli("edit", filePath); await c.log(studioLog(studioEmoji.edit, `Edit ${filePath}`));
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
          logger.cli("batch"); await c.log(studioLog(studioEmoji.batch, "Run batch"));
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
          logger.cli("find-replace"); await c.log(studioLog(studioEmoji.replace, "Find and replace"));
          return c.findReplace(paths, oldString, newString || "");
        });
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case "search": {
        const keywords = args.join(" ");
        const result = await withClient(async (c) => {
          logger.cli("search"); await c.log(studioLog(studioEmoji.search, "Search scripts"));
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

        const runWithClient = targets.length > 0 ? withClient : withDaemonClient;
        await runWithClient(async (client) => {
          logger.cli("pull", outputDir); await client.log(studioLog(studioEmoji.pull, `Pull scripts to ${outputDir}`));
          const puller = new Puller(client, {
            outputDir,
            targets: targets.length > 0 ? targets : undefined,
            concurrency: 16,
            delayMs: 0,
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
        await withDaemonClient(async (client) => {
          const pusher = new Pusher(client, { projectDir });
          const { changed, studioPath, result } = await pusher.push(file);
          if (!changed) {
            console.log(`No changes for ${studioPath}`);
          } else {
            console.log(`Pushed ${file} -> ${studioPath}`);
            console.log(JSON.stringify(result, null, 2));
          }
          logger.cli("push", `${file} -> ${studioPath}`); await client.log(studioLog(studioEmoji.push, `Push ${file}`));
        });
        break;
      }


      case "plugin": {
        const [sub, ...pluginArgs] = args;
        const result = await withDaemonClient(async (c) => {
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
          if (sub === "inspect") {
            if (!pluginArgs[0]) throw new Error("Usage: mcp plugin inspect <path>");
            return c.pluginCall({ type: "get_children", path: pluginArgs[0] });
          }
          if (sub === "select") {
            if (pluginArgs.length === 0) throw new Error("Usage: mcp plugin select <path...>");
            return c.pluginCall({ type: "set_selection", paths: pluginArgs });
          }
          if (sub === "open") {
            if (!pluginArgs[0]) throw new Error("Usage: mcp plugin open <path> [line]");
            return c.pluginCall({
              type: "open_script",
              path: pluginArgs[0],
              line: pluginArgs[1] ? Number(pluginArgs[1]) : 1,
            });
          }
          if (sub === "call") {
            const [type, ...inputArgs] = pluginArgs;
            if (!type) throw new Error("Usage: mcp plugin call <type> [json|--json-file <file>|--json-stdin]");
            const commandArguments = await readJsonObjectArgument(inputArgs);
            return c.pluginCall({ ...commandArguments, type });
          }
          throw new Error(
            "Usage: mcp plugin [status|events|selection|state|inspect|select|open|call]",
          );
        });
        console.log(JSON.stringify(result, null, 2));
        break;
      }

      case "pending": {
        const sub = args[0];
        if (sub === "verify") {
          try {
            const result = await withClient(async (c) => c.pendingVerify());
            console.log(JSON.stringify(result, null, 2));
          } catch (err) {
            if (err.code === "ECONNREFUSED" || err.message?.includes("fetch failed") || err.message?.includes("ECONNREFUSED") || err.message?.includes("connect")) {
              console.log(JSON.stringify({
                ok: false,
                reason: "host_disconnected",
                error: "Cannot verify pending edits: Abraxius app host is disconnected. Start Abraxius.App or run 'node server.js start'.",
                connected: false,
              }, null, 2));
            } else {
              throw err;
            }
          }
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
          logger.cli("repl state"); await client.log(studioLog(studioEmoji.repl, "Read Studio state (REPL)"));
          console.log(JSON.stringify(await client.state(), null, 2));
          continue;
        }
        if (trimmed === "context") {
          console.log(JSON.stringify(await client.context(), null, 2));
          continue;
        }
        if (trimmed.startsWith("execute ")) {
          const code = trimmed.slice(8);
          logger.cli("repl execute"); await client.log(studioLog(studioEmoji.execute, "Execute Luau (REPL)"));
          console.log(JSON.stringify(await client.execute(code), null, 2));
          continue;
        }

        const useSmart = trimmed.startsWith("smart ");
        const rest = useSmart ? trimmed.slice(6) : trimmed;
        const parts = rest.split(/\s+/);
        const [name, ...jsonParts] = parts;
        const json = jsonParts.join(" ");
        await client.log(
          studioLog(studioEmoji.repl, `${useSmart ? "Smart call" : "Call"} ${name} (REPL)`),
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

if (require.main === module) {
  main();
}

module.exports = {
  parseOptions,
  USAGE,
};

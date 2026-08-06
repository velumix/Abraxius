const WebSocket = require("ws");
const os = require("os");
const path = require("path");
const fs = require("fs");
const { spawn } = require("child_process");
const { OllamaClient, loadOllamaSettings } = require("./ollama");

const MUTATING_TOOLS = new Set(["multi_edit", "edit_script", "execute_luau", "push", "find_replace", "batch"]);
const SELECTION_TOOL = {
  name: "get_selection",
  description: "Return the instances currently selected in Roblox Studio Explorer. Read-only.",
  inputSchema: { type: "object", properties: {}, additionalProperties: false },
  annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true },
};
const SEARCH_SCRIPTS_TOOL = {
  name: "search_scripts",
  description: "Search Roblox script source and names. Read-only compatibility tool.",
  inputSchema: { type: "object", properties: { query: { type: "string" }, scope: { type: "string" } }, required: ["query"] },
  annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true },
};
const HIERARCHY_TOOL = {
  name: "get_hierarchy",
  description: "Explore the Roblox instance hierarchy. Read-only.",
  inputSchema: { type: "object", properties: { path: { type: "string" }, max_depth: { type: "number" }, head_limit: { type: "number" } } },
  annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true },
};
const READ_SCRIPT_TOOL = {
  name: "read_script",
  description: "Read a Roblox script source file. Read-only.",
  inputSchema: { type: "object", properties: { path: { type: "string" }, target_file: { type: "string" }, should_read_entire_file: { type: "boolean" } } },
  annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true },
};
const OLLAMA_LIST_TOOL = {
  name: "ollama_list_models",
  description: "List models installed in the local Ollama daemon. Read-only.",
  inputSchema: { type: "object", properties: {}, additionalProperties: false },
  annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true },
};
const OLLAMA_PULL_TOOL = {
  name: "ollama_pull_model",
  description: "Download a model into the local Ollama daemon. Requires approval.",
  inputSchema: { type: "object", required: ["model"], properties: { model: { type: "string" } } },
  annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true },
};
const OLLAMA_CHAT_TOOL = {
  name: "ollama_chat",
  description: "Ask the local Ollama interpreter for the next reasoning step or prompt. Read-only.",
  inputSchema: {
    type: "object",
    required: ["prompt"],
    properties: {
      prompt: { type: "string" },
      model: { type: "string" },
      temperature: { type: "number" },
      num_ctx: { type: "number" },
    },
  },
  annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: false },
};
const PROJECT_TOOLS = [
  { name: "list_directory", description: "List an approved project directory. Read-only.", inputSchema: { type: "object", properties: { path: { type: "string" }, depth: { type: "number" } } }, annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true } },
  { name: "read_file", description: "Read an approved local project file. Read-only.", inputSchema: { type: "object", required: ["path"], properties: { path: { type: "string" }, max_bytes: { type: "number" } } }, annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true } },
  { name: "search_files", description: "Search approved project files with ripgrep. Read-only.", inputSchema: { type: "object", required: ["query"], properties: { query: { type: "string" }, path: { type: "string" }, glob: { type: "string" } } }, annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true } },
  { name: "git_status", description: "Show Git status for an approved project. Read-only.", inputSchema: { type: "object", properties: { path: { type: "string" } } }, annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true } },
  { name: "git_diff", description: "Show Git diff for an approved project. Read-only.", inputSchema: { type: "object", properties: { path: { type: "string" }, staged: { type: "boolean" } } }, annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true } },
  { name: "apply_patch", description: "Apply a patch inside an approved project. Requires approval.", inputSchema: { type: "object", required: ["patch"], properties: { patch: { type: "string" }, cwd: { type: "string" } } }, annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false } },
  { name: "run_command", description: "Run an allowlisted command in an approved project. Requires approval.", inputSchema: { type: "object", required: ["command"], properties: { command: { type: "string" }, cwd: { type: "string" }, timeout_ms: { type: "number" } } }, annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false } },
  { name: "create_directory", description: "Create a directory inside an approved project. Requires approval.", inputSchema: { type: "object", required: ["path"], properties: { path: { type: "string" } } }, annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true } },
  { name: "create_file", description: "Create or overwrite a file inside an approved project. Requires approval.", inputSchema: { type: "object", required: ["path", "content"], properties: { path: { type: "string" }, content: { type: "string" } } }, annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false } },
];
// Stable names used by browser chatbots that do not understand Abraxius'
// longer internal names. These are compatibility aliases, not extra powers.
const COMPAT_TOOLS = [
  { name: "inspect_project", description: "Inspect the approved project and return its context and top-level files. Read-only.", inputSchema: { type: "object", properties: { path: { type: "string" } } }, annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true } },
  { name: "list_tools", description: "List the tools currently exposed by Abraxius. Read-only.", inputSchema: { type: "object", properties: {} }, annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true } },
  { name: "list_files", description: "List files in the approved project. Read-only compatibility alias.", inputSchema: { type: "object", properties: { path: { type: "string" }, depth: { type: "number" } } }, annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true } },
  { name: "search_code", description: "Search approved project source. Read-only compatibility alias.", inputSchema: { type: "object", required: ["query"], properties: { query: { type: "string" }, path: { type: "string" } } }, annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true } },
  { name: "edit_file", description: "Apply a patch to an approved project file. Requires approval.", inputSchema: { type: "object", required: ["patch"], properties: { patch: { type: "string" }, cwd: { type: "string" } } }, annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false } },
];
const PROJECT_MUTATIONS = new Set(["apply_patch", "run_command"]);
const ALLOWED_COMMANDS = new Set(["git", "rg", "fd", "node", "npm", "pnpm", "cargo", "rojo", "selene", "stylua", "luau-lsp", "ollama"]);
function resolveNodeBinary() {
  const candidates = [
    process.env.ABRAXIUS_NODE_PATH,
    "/usr/bin/node",
    "/usr/local/bin/node",
    ...(() => {
      try {
        const root = path.join(os.homedir(), ".local/share/zed/node");
        return fs.readdirSync(root).map((entry) => path.join(root, entry, "bin/node"));
      } catch { return []; }
    })(),
  ].filter(Boolean);
  return candidates.find((candidate) => fs.existsSync(candidate)) || "node";
}

class AiToolWebSocketServer {
  constructor({ port = 13473, path: routePath = "/ai", bridge, context, pendingPushes, pluginServer, buildContext, allowedRoots }) {
    this.port = port; this.path = routePath; this.bridge = bridge; this.context = context;
    this.pendingPushes = pendingPushes; this.pluginServer = pluginServer; this.buildContext = buildContext; this.server = null;
    this.allowedRoots = (allowedRoots || [process.cwd()]).map((root) => path.resolve(root));
    this.browserSocket = null;
    this.browserPending = new Map();
  }
  resolveProjectPath(value = ".", { mustExist = false } = {}) {
    const valStr = String(value || ".");
    let candidate = null;
    for (const root of this.allowedRoots) {
      const resolved = path.resolve(root, valStr);
      if (this.allowedRoots.some((r) => resolved === r || resolved.startsWith(`${r}${path.sep}`))) {
        if (!mustExist || fs.existsSync(resolved)) {
          candidate = resolved;
          break;
        }
      }
    }
    if (!candidate) {
      candidate = path.resolve(this.allowedRoots[0], valStr);
    }
    if (!this.allowedRoots.some((root) => candidate === root || candidate.startsWith(`${root}${path.sep}`))) {
      throw new Error("Path is outside approved Abraxius project roots");
    }
    if (mustExist && !fs.existsSync(candidate)) {
      throw new Error("Path does not exist");
    }
    return candidate;
  }
  relativeToAllowedRoot(target) {
    for (const root of this.allowedRoots) {
      if (target === root || target.startsWith(`${root}${path.sep}`)) {
        const rel = path.relative(root, target);
        return rel || ".";
      }
    }
    return path.relative(this.allowedRoots[0], target) || target;
  }
  async runAllowedCommand(command, cwd, timeoutMs = 30000, input = null) {
    const parts = String(command || "").trim().split(/\s+/);
    const executable = path.basename(parts.shift() || "");
    if (!ALLOWED_COMMANDS.has(executable)) throw new Error(`Command is not allowlisted: ${executable}`);
    let workingDirectory = this.resolveProjectPath(cwd || ".", { mustExist: true });
    if (fs.existsSync(workingDirectory) && !fs.statSync(workingDirectory).isDirectory()) {
      workingDirectory = path.dirname(workingDirectory);
    }
    return new Promise((resolve, reject) => {
      // Electron may not inherit the user's Zed-managed PATH. Resolve node
      // through the running process so `node cli.js …` works from the bridge.
      const nodeBin = resolveNodeBinary();
      const nodeDir = path.dirname(nodeBin);
      const execDir = path.dirname(process.execPath);
      const extraPaths = [nodeDir, execDir, "/usr/local/bin", "/usr/bin", "/bin"].filter(Boolean);
      const envPath = [process.env.PATH || "", ...extraPaths].join(path.delimiter);
      const commandPath = executable === "node" ? nodeBin : executable;
      const child = spawn(commandPath, parts, { cwd: workingDirectory, env: { ...process.env, PATH: envPath, HOME: os.homedir(), LANG: "C.UTF-8" }, stdio: [input === null ? "ignore" : "pipe", "pipe", "pipe"] });
      let stdout = ""; let stderr = ""; const limit = 50000;
      child.stdout.on("data", (chunk) => { stdout = `${stdout}${chunk}`.slice(-limit); });
      child.stderr.on("data", (chunk) => { stderr = `${stderr}${chunk}`.slice(-limit); });
      if (input !== null) { child.stdin.end(String(input)); }
      const timer = setTimeout(() => { child.kill("SIGTERM"); resolve({ exitCode: null, stdout, stderr, timedOut: true }); }, Math.min(120000, Math.max(1000, Number(timeoutMs) || 30000)));
      child.on("error", (error) => { clearTimeout(timer); reject(error); });
      child.on("close", (code) => { clearTimeout(timer); resolve({ exitCode: code, stdout, stderr, timedOut: false }); });
    });
  }
  start() {
    if (this.server) throw new Error("AI tool WebSocket server already started");
    return new Promise((resolve, reject) => {
      this.server = new WebSocket.Server({ host: "127.0.0.1", port: this.port, path: this.path });
      this.server.once("listening", () => resolve({ port: this.port, path: this.path }));
      this.server.once("error", reject);
      this.server.on("connection", (socket) => this._connection(socket));
    });
  }
  stop() {
    this._rejectBrowserPending(new Error("Brave extension bridge stopped"));
    if (this.server) { this.server.close(); this.server = null; }
  }
  _send(socket, id, result, error) {
    if (socket.readyState !== WebSocket.OPEN) return;
    socket.send(JSON.stringify(error ? { id, error: error.message || String(error) } : { id, result }));
  }
  _connection(socket) {
    socket.on("close", () => {
      this._rejectBrowserPending(new Error("Brave extension disconnected"), socket);
      if (this.browserSocket === socket) this.browserSocket = null;
    });
    socket.on("message", async (raw) => {
      let message;
      try { message = JSON.parse(raw.toString()); } catch { return this._send(socket, null, null, new Error("Invalid JSON")); }
      if (!message || typeof message !== "object") return;
      if (message.type === "browser_result" && this.browserPending.has(message.id)) {
        const pending = this.browserPending.get(message.id);
        this.browserPending.delete(message.id);
        if (message.error) pending.reject(new Error(message.error)); else pending.resolve(message.result);
        return;
      }
      try { this._send(socket, message.id ?? null, await this._handle(message.method, message.params || {}, socket)); }
      catch (error) { this._send(socket, message.id ?? null, null, error); }
    });
  }
  _rejectBrowserPending(error, socket = null) {
    for (const [id, pending] of this.browserPending) {
      if (socket && pending.socket !== socket) continue;
      this.browserPending.delete(id);
      pending.reject(error);
    }
  }
  async _handle(method, params, socket) {
    if (method === "ping") return { ok: true };
    if (method === "initialize") {
      if (params.role === "browser_extension") this.browserSocket = socket;
      return { protocolVersion: "2024-11-05", serverInfo: { name: "abraxius-ai-tools", version: "1.0.0" }, capabilities: { tools: true, context: true, approvals: true, browserControl: true } };
    }
    if (method === "browser/register") {
      this.browserSocket = socket;
      return { ok: true, browserControl: true };
    }
    if (method === "browser/send") {
      if (!this.browserSocket || this.browserSocket.readyState !== WebSocket.OPEN) throw new Error("Brave extension is not connected");
      const commandId = `browser-${Date.now()}-${Math.random().toString(36).slice(2)}`;
      const browserSocket = this.browserSocket;
      const result = new Promise((resolve, reject) => {
        const timeoutMs = params.command === "page/wait_for_reply" ? 610000 : 10000;
        const timer = setTimeout(() => { this.browserPending.delete(commandId); reject(new Error("Brave extension command timed out")); }, timeoutMs);
        this.browserPending.set(commandId, { socket: browserSocket, resolve: (value) => { clearTimeout(timer); resolve(value); }, reject: (error) => { clearTimeout(timer); reject(error); } });
      });
      try {
        browserSocket.send(JSON.stringify({ type: "browser_command", id: commandId, command: params.command, payload: params.payload || {} }));
      } catch (error) {
        this._rejectBrowserPending(error, browserSocket);
      }
      return result;
    }
    if (method === "tools/list") {
      const tools = this.bridge.ready ? await this.bridge.listTools() : [];
      if (this.pluginServer?.isConnected?.() && !tools.some((tool) => tool.name === SELECTION_TOOL.name)) tools.push(SELECTION_TOOL);
      if (this.bridge.ready && !tools.some((tool) => tool.name === SEARCH_SCRIPTS_TOOL.name)) tools.push(SEARCH_SCRIPTS_TOOL);
      if (this.bridge.ready && !tools.some((tool) => tool.name === HIERARCHY_TOOL.name)) tools.push(HIERARCHY_TOOL);
      if (this.bridge.ready && !tools.some((tool) => tool.name === READ_SCRIPT_TOOL.name)) tools.push(READ_SCRIPT_TOOL);
      if (!tools.some((tool) => tool.name === OLLAMA_LIST_TOOL.name)) tools.push(OLLAMA_LIST_TOOL);
      if (!tools.some((tool) => tool.name === OLLAMA_PULL_TOOL.name)) tools.push(OLLAMA_PULL_TOOL);
      if (!tools.some((tool) => tool.name === OLLAMA_CHAT_TOOL.name)) tools.push(OLLAMA_CHAT_TOOL);
      for (const tool of PROJECT_TOOLS) if (!tools.some((item) => item.name === tool.name)) tools.push(tool);
      for (const tool of COMPAT_TOOLS) if (!tools.some((item) => item.name === tool.name)) tools.push(tool);
      return { tools, connected: this.bridge.ready };
    }
    if (method === "context/get") return this.buildContext({ context: this.context, pendingPushes: this.pendingPushes, pluginServer: this.pluginServer, projectDir: params.projectDir });
    if (method === "tools/call") {
      const { name, arguments: args = {}, approved = false } = params;
      if (!name) throw new Error("Missing tool name");
      if (name === "list_tools") return this._handle("tools/list", {}, socket);
      if (name === "inspect_project") {
        const projectPath = args.path || ".";
        const context = await this._handle("context/get", { projectDir: projectPath }, socket);
        const files = await this._handle("tools/call", { name: "list_directory", arguments: { path: projectPath, depth: 1 }, approved: true }, socket);
        // Keep browser chatbot DOM updates bounded; detailed files can be
        // requested separately with read_file/search_code.
        const contextText = JSON.stringify(context);
        return {
          context: contextText.length > 24000 ? { summary: contextText.slice(0, 24000), truncated: true } : context,
          files: { ...files, entries: (files.entries || []).slice(0, 120), truncated: (files.entries || []).length > 120 },
        };
      }
      if (name === "list_files") return this._handle("tools/call", { name: "list_directory", arguments: args, approved: true }, socket);
      if (name === "search_code") return this._handle("tools/call", { name: "search_files", arguments: args, approved: true }, socket);
      if (name === "edit_file") return this._handle("tools/call", { name: "apply_patch", arguments: args, approved }, socket);
      if (name === "get_selection") {
        // Prefer the event cache, but allow the live Studio bridge to answer
        // when the companion heartbeat is stale. This prevents a healthy
        // Studio connection from being reported as unusable just because the
        // plugin event session expired.
        if (!this.pluginServer?.isConnected?.() && !this.bridge.ready) throw new Error("Roblox Studio companion is not connected");
        const recent = this.pluginServer.listEvents?.({ limit: 100 }) || [];
        const selectionEvent = recent.find((event) => event?.type === "selection_changed");
        let result;
        if (selectionEvent) {
          result = { ok: true, selection: (selectionEvent.paths || []).map((path) => ({ path })) };
        } else if (this.bridge.ready) {
          // The companion command queue can stall while Studio is changing
          // focus. Execute the read-only Selection query through the active
          // Studio tool channel instead of timing out.
          result = await this.bridge.callTool("execute_luau", {
            datamodel_type: "Edit",
            code: 'local s=game:GetService("Selection"):Get(); local out={}; for i,v in ipairs(s) do out[i]=v:GetFullName() end; return out',
          });
        } else {
          result = await this.pluginServer.callPlugin({ type: "get_selection" });
        }
        this.context.record({ type: "call", target: "selection", datamodel: this.context.preferredDatamodel, summary: name });
        return result;
      }
      if (name === "search_scripts") {
        if (!this.bridge.ready) throw new Error("Roblox Studio is not connected");
        const query = String(args.query || "").trim();
        if (!query) throw new Error("search_scripts requires query");
        return this.bridge.callTool("script_grep", { query });
      }
      if (name === "get_hierarchy") {
        if (!this.bridge.ready) throw new Error("Roblox Studio is not connected");
        return this.bridge.callTool("search_game_tree", {
          ...args,
          max_depth: Math.min(Number(args.max_depth) || 3, 4),
          head_limit: Math.min(Number(args.head_limit) || 80, 120),
        });
      }
      if (name === "read_script") {
        if (!this.bridge.ready) throw new Error("Roblox Studio is not connected");
        return this.bridge.callTool("script_read", {
          target_file: args.target_file || args.path,
          should_read_entire_file: args.should_read_entire_file !== false,
        });
      }
      if (name === "ollama_list_models") {
        const settings = loadOllamaSettings(path.join(os.homedir(), ".config/abraxius"));
        return { models: await new OllamaClient({ endpoint: settings.endpoint }).listModels(), endpoint: settings.endpoint };
      }
      if (name === "ollama_pull_model") {
        if (!approved) return { approvalRequired: true, name, arguments: args };
        const model = String(args.model || "").trim();
        if (!/^[A-Za-z0-9_.:/-]{1,160}$/.test(model)) throw new Error("Invalid Ollama model tag");
        const settings = loadOllamaSettings(path.join(os.homedir(), ".config/abraxius"));
        const result = await new OllamaClient({ endpoint: settings.endpoint }).pullModel({ model });
        return { ...result, model, endpoint: settings.endpoint };
      }
      if (name === "ollama_chat") {
        const prompt = String(args.prompt || "").trim();
        if (!prompt) throw new Error("ollama_chat requires prompt");
        const settings = loadOllamaSettings(path.join(os.homedir(), ".config/abraxius"));
        const client = new OllamaClient({ endpoint: settings.endpoint });
        const chunks = [];
        const result = await client.streamChat({
          model: String(args.model || settings.selectedModel || "qwen3.5:9b-q4_K_M"),
          messages: [{ role: "user", content: prompt }],
          endpoint: settings.endpoint,
          temperature: args.temperature === undefined ? 0.2 : Number(args.temperature),
          numCtx: args.num_ctx === undefined ? 16384 : Number(args.num_ctx),
          onChunk: (chunk) => chunks.push(chunk),
        });
        return { ok: true, model: String(args.model || settings.selectedModel || "qwen3.5:9b-q4_K_M"), response: result.fullText || chunks.join("") };
      }
      if (PROJECT_TOOLS.some((tool) => tool.name === name)) {
        if (name === "list_directory") {
          const root = this.resolveProjectPath(args.path || ".", { mustExist: true });
          const depth = Math.min(3, Math.max(0, Number(args.depth) || 1));
          const walk = (dir, level) => fs.readdirSync(dir, { withFileTypes: true }).slice(0, 200).flatMap((entry) => {
            const full = path.join(dir, entry.name); const item = { path: path.relative(this.allowedRoots[0], full), type: entry.isDirectory() ? "directory" : "file" };
            return entry.isDirectory() && level < depth ? [item, ...walk(full, level + 1)] : [item];
          });
          return { root: path.relative(this.allowedRoots[0], root) || ".", entries: walk(root, 0) };
        }
        if (name === "read_file") {
          const target = this.resolveProjectPath(args.path, { mustExist: true });
          if (!fs.statSync(target).isFile()) throw new Error("read_file target is not a file");
          return { path: path.relative(this.allowedRoots[0], target), content: fs.readFileSync(target, "utf8").slice(0, Math.min(200000, Number(args.max_bytes) || 50000)) };
        }
        if (name === "search_files") {
          const root = this.resolveProjectPath(args.path || ".", { mustExist: true });
          const needle = String(args.query || "");
          if (!needle) throw new Error("search_files requires query");
          const results = []; const pattern = new RegExp(needle.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "i");
          const visit = (dir) => {
            if (results.length >= 200) return;
            for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
              if (entry.name === "node_modules" || entry.name === ".git" || entry.name.startsWith(".")) continue;
              const full = path.join(dir, entry.name);
              if (entry.isDirectory()) visit(full);
              else if (entry.isFile()) {
                try { const lines = fs.readFileSync(full, "utf8").split(/\r?\n/); lines.forEach((line, index) => { if (results.length < 200 && pattern.test(line)) results.push({ path: path.relative(this.allowedRoots[0], full), line: index + 1, text: line.slice(0, 500) }); }); } catch {}
              }
            }
          };
          visit(root);
          return { query: needle, results, truncated: results.length >= 200 };
        }
        if (name === "git_status") return this.runAllowedCommand("git status --short", args.path || ".");
        if (name === "git_diff") {
          const target = this.resolveProjectPath(args.path || ".", { mustExist: true });
          const isDir = fs.statSync(target).isDirectory();
          const targetDir = isDir ? target : path.dirname(target);
          const relTarget = isDir ? "." : path.relative(targetDir, target);
          const baseCmd = args.staged ? "git diff --cached" : "git diff";
          const cmd = relTarget !== "." ? `${baseCmd} -- ${relTarget}` : baseCmd;
          return this.runAllowedCommand(cmd, targetDir);
        }
        if (!approved) return { approvalRequired: true, name, arguments: args };
        if (name === "create_directory") {
          const target = this.resolveProjectPath(args.path, { mustExist: false });
          fs.mkdirSync(target, { recursive: true });
          return { ok: true, path: this.relativeToAllowedRoot(target) };
        }
        if (name === "create_file") {
          const target = this.resolveProjectPath(args.path, { mustExist: false });
          if (fs.existsSync(target) && fs.statSync(target).isDirectory()) throw new Error("create_file target is a directory");
          fs.mkdirSync(path.dirname(target), { recursive: true });
          fs.writeFileSync(target, String(args.content || ""), "utf8");
          return { ok: true, path: this.relativeToAllowedRoot(target), bytes: Buffer.byteLength(String(args.content || "")) };
        }
function applyCustomUpdate(existingContent, blockText, actionLines) {
  const normContent = String(existingContent || "").replace(/\r\n/g, "\n");
  if (blockText.includes("<<<<<<< SEARCH")) {
    const parts = blockText.split("<<<<<<< SEARCH");
    let result = normContent;
    for (let i = 1; i < parts.length; i++) {
      const sub = parts[i];
      const endSearchIdx = sub.indexOf("=======");
      const endReplaceIdx = sub.indexOf(">>>>>>> REPLACE");
      if (endSearchIdx !== -1 && endReplaceIdx !== -1) {
        const searchStr = sub.slice(0, endSearchIdx).replace(/^\n/, "").replace(/\n$/, "");
        const replaceStr = sub.slice(endSearchIdx + 7, endReplaceIdx).replace(/^\n/, "").replace(/\n$/, "");
        if (result.includes(searchStr)) {
          result = result.replace(searchStr, replaceStr);
        } else {
          const normSearch = searchStr.replace(/\r\n/g, "\n");
          const normReplace = replaceStr.replace(/\r\n/g, "\n");
          if (result.includes(normSearch)) {
            result = result.replace(normSearch, normReplace);
          }
        }
      }
    }
    return result;
  }
  if (blockText.includes("*** Replace:")) {
    const parts = blockText.split("*** Replace:");
    let result = normContent;
    for (let i = 1; i < parts.length; i++) {
      const sub = parts[i];
      const withIdx = sub.indexOf("*** With:");
      if (withIdx !== -1) {
        const searchStr = sub.slice(0, withIdx).trim();
        const replaceStr = sub.slice(withIdx + 8).trim();
        if (result.includes(searchStr)) {
          result = result.replace(searchStr, replaceStr);
        }
      }
    }
    return result;
  }
  if (actionLines.some((l) => l.startsWith("+") || l.startsWith("-") || l.startsWith("@@"))) {
    const removeLines = [];
    const addLines = [];
    const contextBefore = [];
    const contextAfter = [];
    let state = "before";
    for (const l of actionLines) {
      if (l.startsWith("---") || l.startsWith("+++") || l.startsWith("@@")) continue;
      if (l.startsWith("-")) {
        removeLines.push(l.slice(1));
        state = "in_change";
      } else if (l.startsWith("+")) {
        addLines.push(l.slice(1));
        state = "in_change";
      } else {
        const lineVal = l.startsWith(" ") ? l.slice(1) : l;
        if (state === "before") contextBefore.push(lineVal); else contextAfter.push(lineVal);
      }
    }
    const removeText = removeLines.join("\n");
    const addText = addLines.join("\n");
    const beforeText = contextBefore.join("\n");
    const afterText = contextAfter.join("\n");
    if (removeText && normContent.includes(removeText)) return normContent.replace(removeText, addText);
    if (beforeText && normContent.includes(beforeText)) {
      const targetAnchor = beforeText + (afterText ? "\n" + afterText : "");
      const replacementAnchor = beforeText + (addText ? "\n" + addText : "") + (afterText ? "\n" + afterText : "");
      if (normContent.includes(targetAnchor)) return normContent.replace(targetAnchor, replacementAnchor);
      return normContent.replace(beforeText, beforeText + (addText ? "\n" + addText : ""));
    }
  }
  return blockText;
}

function parseAndApplyBeginPatch(patchStr, cwdDir, resolveProjectPathFn) {
  const lines = String(patchStr || "").split(/\r?\n/);
  let inPatch = false;
  let currentAction = null;
  const fileActions = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();
    if (trimmed.startsWith("*** Begin Patch")) { inPatch = true; continue; }
    if (trimmed.startsWith("*** End Patch")) {
      if (currentAction) { fileActions.push(currentAction); currentAction = null; }
      inPatch = false; break;
    }
    if (!inPatch) continue;
    if (trimmed.startsWith("*** Add File:")) {
      if (currentAction) fileActions.push(currentAction);
      currentAction = { type: "add", relPath: trimmed.slice("*** Add File:".length).trim(), lines: [] };
      continue;
    }
    if (trimmed.startsWith("*** Update File:")) {
      if (currentAction) fileActions.push(currentAction);
      currentAction = { type: "update", relPath: trimmed.slice("*** Update File:".length).trim(), lines: [] };
      continue;
    }
    if (trimmed.startsWith("*** Delete File:")) {
      if (currentAction) fileActions.push(currentAction);
      currentAction = { type: "delete", relPath: trimmed.slice("*** Delete File:".length).trim(), lines: [] };
      continue;
    }
    if (currentAction) currentAction.lines.push(line);
  }
  if (currentAction) fileActions.push(currentAction);
  if (fileActions.length === 0) throw new Error("No file actions found in patch payload");
  const results = [];
  for (const action of fileActions) {
    const targetPath = path.isAbsolute(action.relPath) ? action.relPath : path.join(cwdDir, action.relPath);
    const fullPath = resolveProjectPathFn(targetPath, { mustExist: action.type !== "add" });
    if (action.type === "add") {
      const content = action.lines.join("\n");
      fs.mkdirSync(path.dirname(fullPath), { recursive: true });
      fs.writeFileSync(fullPath, content, "utf8");
      results.push({ action: "add", path: action.relPath });
    } else if (action.type === "delete") {
      if (fs.existsSync(fullPath)) fs.unlinkSync(fullPath);
      results.push({ action: "delete", path: action.relPath });
    } else if (action.type === "update") {
      const existingContent = fs.readFileSync(fullPath, "utf8");
      const blockText = action.lines.join("\n");
      const updated = applyCustomUpdate(existingContent, blockText, action.lines);
      fs.writeFileSync(fullPath, updated, "utf8");
      results.push({ action: "update", path: action.relPath });
    }
  }
  return { exitCode: 0, stdout: `Applied ${results.length} patch action(s)`, stderr: "", timedOut: false };
}

        if (name === "apply_patch") {
          const targetPath = args.cwd || args.path || ".";
          let resolved;
          try {
            resolved = this.resolveProjectPath(targetPath, { mustExist: true });
          } catch {
            resolved = this.resolveProjectPath(targetPath, { mustExist: false });
          }
          const cwd = fs.existsSync(resolved) && fs.statSync(resolved).isDirectory() ? resolved : path.dirname(resolved);
          if (typeof args.patch === "string" && args.patch.includes("*** Begin Patch")) {
            return parseAndApplyBeginPatch(args.patch, cwd, (p, opts) => this.resolveProjectPath(p, opts));
          }
          return this.runAllowedCommand("git apply --whitespace=nowarn", cwd, 30000, args.patch);
        }
        return this.runAllowedCommand(args.command, args.cwd || ".", args.timeout_ms);
      }
      if (!this.bridge.ready) throw new Error("Roblox Studio is not connected");
      if (MUTATING_TOOLS.has(name) && !approved) return { approvalRequired: true, name, arguments: args };
      const result = await this.bridge.callTool(name, args);
      this.context.record({ type: "call", target: args.file_path || args.target_file || name, datamodel: args.datamodel_type || this.context.preferredDatamodel, summary: name });
      if (name === "multi_edit" && args.file_path && args.edits?.[0] && typeof args.edits[0].new_string === "string") {
        this.pendingPushes.recordPush(args.file_path, args.edits[0].new_string);
      }
      return result;
    }
    throw new Error(`Unknown method: ${method}`);
  }
}

module.exports = { AiToolWebSocketServer, MUTATING_TOOLS };

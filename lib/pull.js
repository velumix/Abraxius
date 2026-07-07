const fs = require("fs");
const path = require("path");
const {
  getScriptExtension,
  ensureDir,
  sanitizeFileName,
  saveProject,
} = require("./project");

const SERVICES = [
  "Workspace",
  "Lighting",
  "ReplicatedFirst",
  "ReplicatedStorage",
  "ServerScriptService",
  "ServerStorage",
  "StarterGui",
  "StarterPack",
  "StarterPlayer",
  "SoundService",
  "Teams",
  "Chat",
  "TextChatService",
];

const SCRIPT_TYPES = ["Script", "LocalScript", "ModuleScript"];

/**
 * Simple concurrency queue with optional delay between task starts.
 * Rate-limits how many MCP requests run at once without adding dependencies.
 */
class Queue {
  constructor(concurrency = 4, delayMs = 0) {
    this.concurrency = concurrency;
    this.delayMs = delayMs;
    this.running = 0;
    this.waiting = [];
  }

  add(fn) {
    return new Promise((resolve, reject) => {
      this.waiting.push({ fn, resolve, reject });
      this._run();
    });
  }

  _run() {
    while (this.running < this.concurrency && this.waiting.length > 0) {
      const { fn, resolve, reject } = this.waiting.shift();
      this.running++;
      this._execute(fn, resolve, reject);
    }
  }

  async _execute(fn, resolve, reject) {
    try {
      if (this.delayMs > 0) await this._sleep(this.delayMs);
      resolve(await fn());
    } catch (err) {
      reject(err);
    } finally {
      this.running--;
      this._run();
    }
  }

  _sleep(ms) {
    return new Promise((r) => setTimeout(r, ms));
  }
}

class Puller {
  constructor(client, options = {}) {
    this.client = client;
    this.outputDir = options.outputDir || ".";
    this.name = options.name || this._defaultName(options.outputDir);
    this.services = options.services || SERVICES;
    this.maxDepth = options.maxDepth || 50;
    this.concurrency = options.concurrency || 4;
    this.delayMs = options.delayMs || 50;
    this.onProgress = options.onProgress || (() => {});
    this.targets = options.targets || null;

    this.stats = { scripts: 0, folders: 0, skipped: 0 };
  }

  _defaultName(outputDir) {
    if (!outputDir || outputDir === ".") return "RobloxPlace";
    return path.basename(path.resolve(outputDir));
  }

  async pull() {
    this.stats = { scripts: 0, folders: 0, skipped: 0 };

    if (this.targets && this.targets.length > 0) {
      return this._pullTargets();
    }

    return this._pullAll();
  }

  async _pullAll() {
    await this.client.state();

    const project = this._emptyProject();
    const queue = new Queue(this.concurrency, this.delayMs);

    // Discover scripts across all services/types in parallel, rate-limited.
    const discoveryTasks = [];
    for (const service of this.services) {
      for (const className of SCRIPT_TYPES) {
        discoveryTasks.push(
          queue.add(() => this._findScriptsOfType(service, className)),
        );
      }
    }
    const results = await Promise.all(discoveryTasks);

    const nodeMap = new Map();
    for (const nodes of results) {
      for (const node of nodes) {
        nodeMap.set(node.fullPath, node);
      }
    }

    // Pull each discovered script in parallel, rate-limited.
    const pullTasks = [];
    for (const node of nodeMap.values()) {
      const service = node.fullPath.split(".")[0];
      const srcDir = path.join(this.outputDir, "src", service);
      ensureDir(srcDir);
      project.tree[service] = { $path: `src/${service}` };
      pullTasks.push(queue.add(() => this._pullScript(node, srcDir, service)));
    }
    await Promise.all(pullTasks);

    saveProject(this.outputDir, project);
    return { project, stats: this.stats };
  }

  async _pullTargets() {
    const project = this._emptyProject();
    const queue = new Queue(this.concurrency, this.delayMs);

    // Resolve each target path to a node in parallel.
    const resolveTasks = this.targets.map((target) =>
      queue.add(() => this._resolveTarget(target)),
    );
    const nodes = await Promise.all(resolveTasks);

    const pullTasks = [];
    for (const node of nodes) {
      if (!node || !getScriptExtension(node.className)) {
        this.stats.skipped++;
        continue;
      }
      const service = node.fullPath.split(".")[0];
      const srcDir = path.join(this.outputDir, "src", service);
      ensureDir(srcDir);
      project.tree[service] = { $path: `src/${service}` };
      pullTasks.push(queue.add(() => this._pullScript(node, srcDir, service)));
    }
    await Promise.all(pullTasks);

    saveProject(this.outputDir, project);
    return { project, stats: this.stats };
  }

  _emptyProject() {
    return {
      name: this.name,
      format: "abraxius-v1",
      tree: { $className: "DataModel" },
    };
  }

  async _findScriptsOfType(service, className) {
    try {
      const result = await this.client.call("search_game_tree", {
        path: service,
        instance_type: className,
        max_depth: this.maxDepth,
        head_limit: 1000,
      });
      const nodes = this._parseTreeNodes(result);
      return nodes.filter((node) => node.className === className);
    } catch (err) {
      // Service might not exist or be empty.
      return [];
    }
  }

  async _resolveTarget(targetPath) {
    const parts = targetPath.split(".");
    if (parts.length < 2) {
      this.onProgress("skip", `Invalid target: ${targetPath}`);
      return null;
    }
    const name = parts[parts.length - 1];
    const parentPath = parts.slice(0, -1).join(".");

    try {
      const result = await this.client.call("search_game_tree", {
        path: parentPath,
        max_depth: 1,
        head_limit: 100,
      });
      const nodes = this._parseTreeNodes(result);
      return nodes.find((node) => node.fullPath === targetPath) || null;
    } catch (err) {
      this.onProgress("skip", `Target not found: ${targetPath}`);
      return null;
    }
  }

  async _pullScript(node, srcDir, service) {
    const ext = getScriptExtension(node.className);
    if (!ext) return;

    const relativePath = node.fullPath.slice(service.length + 1);
    const parts = relativePath.split(".");
    const fileName = sanitizeFileName(parts.pop());
    const dirParts = parts.map(sanitizeFileName);
    const scriptDir = path.join(srcDir, ...dirParts);
    ensureDir(scriptDir);

    this.onProgress("read", node.fullPath);
    const readResult = await this.client.call("script_read", {
      target_file: node.fullPath,
      should_read_entire_file: true,
    });
    const source = this._extractScriptSource(readResult);

    const hasChildren = await this._hasChildren(node.fullPath);

    if (hasChildren) {
      const childDir = path.join(scriptDir, fileName);
      ensureDir(childDir);
      fs.writeFileSync(path.join(childDir, `init${ext}`), source);
      this.stats.scripts++;
    } else {
      fs.writeFileSync(path.join(scriptDir, `${fileName}${ext}`), source);
      this.stats.scripts++;
    }
  }

  async _hasChildren(fullPath) {
    try {
      const result = await this.client.call("search_game_tree", {
        path: fullPath,
        max_depth: 1,
        head_limit: 100,
      });
      const nodes = this._parseTreeNodes(result);
      return nodes.length > 1;
    } catch {
      return false;
    }
  }

  _parseTreeNodes(result) {
    try {
      const text = result.content[0].text;
      const jsonStart = text.indexOf("[");
      if (jsonStart === -1) return [];
      return JSON.parse(text.slice(jsonStart));
    } catch {
      return [];
    }
  }

  _extractScriptSource(readResult) {
    try {
      const text = readResult.content[0].text;
      const lines = text.split("\n");
      const sourceLines = lines
        .map((line) => {
          const arrow = line.indexOf("→");
          return arrow === -1 ? line : line.slice(arrow + 1);
        })
        .join("\n");
      return sourceLines;
    } catch {
      return "-- failed to read source\n";
    }
  }
}

module.exports = { Puller, SERVICES, SCRIPT_TYPES, Queue };

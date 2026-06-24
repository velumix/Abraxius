const fs = require("fs");
const path = require("path");
const {
  isScriptClass,
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

class Puller {
  constructor(client, options = {}) {
    this.client = client;
    this.outputDir = options.outputDir || ".";
    this.name = options.name || this._defaultName(options.outputDir);
    this.services = options.services || SERVICES;
    this.maxDepth = options.maxDepth || 50;
    this.onProgress = options.onProgress || (() => {});

    this.stats = { scripts: 0, folders: 0, skipped: 0 };
  }

  _defaultName(outputDir) {
    if (!outputDir || outputDir === ".") return "RobloxPlace";
    return path.basename(path.resolve(outputDir));
  }

  async pull() {
    this.stats = { scripts: 0, folders: 0, skipped: 0 };

    const state = await this.client.state();
    const project = {
      name: this.name,
      format: "abraxius-v1",
      tree: {
        $className: "DataModel",
      },
    };

    for (const service of this.services) {
      const scripts = await this._findScripts(service);
      if (scripts.length === 0) continue;

      const srcDir = path.join(this.outputDir, "src", service);
      ensureDir(srcDir);
      project.tree[service] = { $path: `src/${service}` };

      for (const script of scripts) {
        await this._pullScript(script, srcDir, service);
      }
    }

    saveProject(this.outputDir, project);
    return { project, stats: this.stats };
  }

  async _findScripts(service) {
    const found = [];
    for (const className of SCRIPT_TYPES) {
      try {
        const result = await this.client.call("search_game_tree", {
          path: service,
          instance_type: className,
          max_depth: this.maxDepth,
          head_limit: 1000,
        });
        const nodes = this._parseTreeNodes(result);
        for (const node of nodes) {
          if (node.className === className) found.push(node);
        }
      } catch (err) {
        // Service might not exist or be empty
      }
    }
    return found;
  }

  async _pullScript(node, srcDir, service) {
    const ext = getScriptExtension(node.className);
    if (!ext) return;

    const relativePath = node.fullPath.slice(service.length + 1); // remove "Service."
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

module.exports = { Puller, SERVICES, SCRIPT_TYPES };

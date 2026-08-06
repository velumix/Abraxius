const fs = require("fs");
const path = require("path");
const { loadProject, getScriptClassFromFile, stripScriptExtension, readMetaProperties } = require("./project");
const { buildSourceEdits, normalizeSource } = require("./source-edits");

function useSourceLineEndings(edits, source) {
  const match = String(source).match(/\r\n|\r|\n/);
  const lineEnding = match ? match[0] : "\n";
  if (lineEnding === "\n") return edits;

  return edits.map((edit) => ({
    ...edit,
    old_string: edit.old_string.replace(/\n/g, lineEnding),
    new_string: edit.new_string.replace(/\n/g, lineEnding),
  }));
}

function resolveStudioPath(projectDir, localFile) {
  const project = loadProject(projectDir);
  if (!project) throw new Error("No place.json found. Run `abraxius pull` first.");

  const absoluteLocal = path.resolve(localFile);
  const absoluteProjectDir = path.resolve(projectDir);

  for (const [serviceName, node] of Object.entries(project.tree)) {
    if (!node || typeof node !== "object" || !node.$path) continue;
    const serviceLocalDir = path.resolve(absoluteProjectDir, node.$path);
    if (!absoluteLocal.startsWith(serviceLocalDir + path.sep)) continue;

    const relative = absoluteLocal.slice(serviceLocalDir.length + 1);
    const parts = relative.split(path.sep);

    const assetFileName = parts[parts.length - 1];
    const assetExtension = path.extname(assetFileName).toLowerCase();
    if (assetExtension === ".rbxm" || assetExtension === ".rbxmx") {
      const assetName = assetFileName.slice(0, -assetExtension.length);
      const parentPath = parts.slice(0, -1).join(".");
      return {
        studioPath: parentPath ? `game.${serviceName}.${parentPath}.${assetName}` : `game.${serviceName}.${assetName}`,
        parentPath: parentPath ? `game.${serviceName}.${parentPath}` : `game.${serviceName}`,
        name: assetName,
        assetType: assetExtension.slice(1),
      };
    }

    if (parts[parts.length - 1].startsWith("init.")) {
      const scriptName = parts[parts.length - 2];
      const parentPath = parts.slice(0, -2).join(".");
      const studioPath = parentPath
        ? `game.${serviceName}.${parentPath}.${scriptName}`
        : `game.${serviceName}.${scriptName}`;
      return {
        studioPath,
        className: getScriptClassFromFile(parts[parts.length - 1]),
        properties: readMetaProperties(localFile),
      };
    }

    const fileName = parts[parts.length - 1];
    const className = getScriptClassFromFile(fileName);
    if (!className) throw new Error(`Not a recognized script file: ${fileName}`);
    const scriptName = stripScriptExtension(fileName);
    const parentPath = parts.slice(0, -1).join(".");
    const studioPath = parentPath
      ? `game.${serviceName}.${parentPath}.${scriptName}`
      : `game.${serviceName}.${scriptName}`;
    return { studioPath, className, properties: readMetaProperties(localFile) };
  }

  throw new Error(`File ${localFile} is not inside any mapped service in place.json`);
}

class Pusher {
  constructor(client, options = {}) {
    this.client = client;
    this.projectDir = options.projectDir || ".";
  }

  async push(localFile) {
    const resolved = resolveStudioPath(this.projectDir, localFile);
    const { studioPath, className, properties } = resolved;
    if (resolved.assetType) return this._pushModel(localFile, resolved);
    // Diff and pending hashes use normalized LF, while multi_edit receives the
    // live script's exact line endings because Studio matches anchors literally.
    const newSource = normalizeSource(fs.readFileSync(localFile, "utf8"));

    const health = await this.client.health();
    if (!health.connected || !health.pluginConnected) {
      throw new Error("Script push requires both Studio MCP and the companion; whole-script fallback is disabled");
    }

    const current = await this.client.pluginCall({ type: "read_source", path: studioPath });
    const currentResult = current && current.result ? current.result : current;
    const exists = currentResult && currentResult.ok === true;
    const edits = exists
      ? useSourceLineEndings(buildSourceEdits(currentResult.source, newSource), currentResult.source)
      : [{ old_string: "", new_string: newSource }];

    if (edits.length > 0) {
      const request = {
        file_path: studioPath,
        datamodel_type: "Edit",
        edits,
      };
      if (!exists) request.className = className;
      const result = await this.client.call("multi_edit", request);
      if (result && result.isError) {
        throw new Error(result.content && result.content[0] ? result.content[0].text : "multi_edit failed");
      }
      if (typeof this.client.pendingRecord === "function") {
        await this.client.pendingRecord(studioPath, newSource);
      }
    }

    if (properties) {
      try {
        await this.client.pluginCall({
          type: "set_properties",
          path: studioPath,
          properties,
        });
      } catch (err) {
        console.warn(`[push] Could not apply properties for ${studioPath}: ${err.message}`);
      }
    }

    const pending = edits.length > 0;

    return {
      changed: edits.length > 0,
      studioPath,
      result: {
        transport: "mcp",
        tool: "multi_edit",
        verified: !pending,
        pending,
        created: !exists,
        editCount: edits.length,
      },
    };
  }

  async _pushModel(localFile, resolved) {
    const bytes = fs.readFileSync(localFile);
    if (bytes.length > 20 * 1024 * 1024) throw new Error("Roblox model assets are limited to 20 MiB");
    const response = await this.client.pluginCall({
      type: "import_model", parent: resolved.parentPath, name: resolved.name,
      format: resolved.assetType, contentBase64: bytes.toString("base64"),
      replace: true, confirm: true,
    });
    const result = response && response.result ? response.result : response;
    if (!result || result.ok !== true) {
      throw new Error(`Companion failed to import ${resolved.studioPath}: ${result?.error || "unknown error"}`);
    }
    const verification = await this.client.pluginCall({ type: "resolve_path", path: resolved.studioPath });
    const verified = verification && verification.result ? verification.result : verification;
    if (!verified || verified.ok !== true || !verified.instance) {
      throw new Error(`Companion model verification failed for ${resolved.studioPath}`);
    }
    return {
      changed: true, studioPath: resolved.studioPath,
      result: { transport: "companion", verified: true, bytes: bytes.length, instance: verified.instance },
    };
  }

}

module.exports = { Pusher, resolveStudioPath, buildSourceEdits };

const fs = require("fs");
const path = require("path");
const { loadProject, getScriptClassFromFile, stripScriptExtension, readMetaProperties } = require("./project");

function resolveStudioPath(projectDir, localFile) {
  const project = loadProject(projectDir);
  if (!project) throw new Error("No place.json found. Run `mcp pull` first.");

  const absoluteLocal = path.resolve(localFile);
  const absoluteProjectDir = path.resolve(projectDir);

  for (const [serviceName, node] of Object.entries(project.tree)) {
    if (!node || typeof node !== "object" || !node.$path) continue;
    const serviceLocalDir = path.resolve(absoluteProjectDir, node.$path);
    if (!absoluteLocal.startsWith(serviceLocalDir + path.sep)) continue;

    const relative = absoluteLocal.slice(serviceLocalDir.length + 1);
    const parts = relative.split(path.sep);

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

function makeLongBracketDelimiter(s) {
  let level = 0;
  while (true) {
    const eq = "=".repeat(level);
    const close = "]" + eq + "]";
    if (!s.includes(close)) return eq;
    level += 1;
  }
}

class Pusher {
  constructor(client, options = {}) {
    this.client = client;
    this.projectDir = options.projectDir || ".";
  }

  async push(localFile) {
    const { studioPath, className, properties } = resolveStudioPath(this.projectDir, localFile);
    const newSource = fs.readFileSync(localFile, "utf8");

    const checkResult = await this.client.call("execute_luau", {
      datamodel_type: "Edit",
      code: `
        local function resolve(path)
          local parts = string.split(path, ".")
          local current = game
          for i = 2, #parts do
            current = current:FindFirstChild(parts[i])
            if current == nil then return nil end
          end
          return current
        end
        local inst = resolve("${studioPath}")
        if inst and inst:IsA("LuaSourceContainer") then
          return { exists = true, sourceLength = #inst.Source, className = inst.ClassName }
        end
        return { exists = false }
      `,
    });

    let exists = false;
    try {
      const text = checkResult.content[0].text;
      const parsed = JSON.parse(text);
      exists = parsed.exists === true;
    } catch {
      exists = false;
    }

    if (exists) {
      const jsonSource = JSON.stringify(newSource);
      const eq = makeLongBracketDelimiter(jsonSource);
      const setResult = await this.client.call("execute_luau", {
        datamodel_type: "Edit",
        code: `
          local HttpService = game:GetService("HttpService")
          local function resolve(path)
            local parts = string.split(path, ".")
            local current = game
            for i = 2, #parts do
              current = current:FindFirstChild(parts[i])
              if current == nil then return nil end
            end
            return current
          end
          local inst = resolve("${studioPath}")
          if inst == nil then error("Instance not found: ${studioPath}") end
          local encoded = [${eq}[${jsonSource}]${eq}]
          inst.Source = HttpService:JSONDecode(encoded)
          return { ok = true, sourceLength = #inst.Source }
        `,
      });
      try {
        const parsed = JSON.parse(setResult.content[0].text);
        if (!parsed.ok) throw new Error("execute_luau source update failed");
      } catch (err) {
        throw new Error(`Failed to update source for ${studioPath}: ${err.message}`);
      }
    } else {
      const result = await this.client.call("multi_edit", {
        file_path: studioPath,
        datamodel_type: "Edit",
        className,
        edits: [{ old_string: "", new_string: newSource }],
      });
      if (result && result.isError) {
        throw new Error(result.content && result.content[0] ? result.content[0].text : "multi_edit failed");
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

    return { changed: true, studioPath };
  }
}

module.exports = { Pusher, resolveStudioPath };

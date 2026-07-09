const fs = require("fs");
const path = require("path");

const SCRIPT_EXTENSIONS = {
  Script: ".server.luau",
  LocalScript: ".client.luau",
  ModuleScript: ".luau",
};

const EXTENSION_TO_CLASS = Object.fromEntries(
  Object.entries(SCRIPT_EXTENSIONS).map(([k, v]) => [v, k]),
);

const META_PROPERTIES = ["RunContext"];

function getScriptExtension(className) {
  return SCRIPT_EXTENSIONS[className] || null;
}

function getScriptClassFromFile(fileName) {
  for (const [ext, cls] of Object.entries(EXTENSION_TO_CLASS)) {
    if (fileName.endsWith(ext)) return cls;
  }
  return null;
}

function stripScriptExtension(name) {
  for (const ext of Object.keys(EXTENSION_TO_CLASS)) {
    if (name.endsWith(ext)) return name.slice(0, -ext.length);
  }
  return name;
}

function isScriptClass(className) {
  return className in SCRIPT_EXTENSIONS;
}

function loadProject(projectDir) {
  const placePath = path.join(projectDir, "place.json");
  if (!fs.existsSync(placePath)) return null;
  return JSON.parse(fs.readFileSync(placePath, "utf8"));
}

function saveProject(projectDir, project) {
  const placePath = path.join(projectDir, "place.json");
  fs.writeFileSync(placePath, JSON.stringify(project, null, 2));
}

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function sanitizeFileName(name) {
  return name.replace(/[\/:*?"<>|]/g, "_");
}

function getMetaPath(filePath) {
  return `${filePath}.meta.json`;
}

function readMetaProperties(filePath) {
  const metaPath = getMetaPath(filePath);
  if (!fs.existsSync(metaPath)) return null;
  try {
    const meta = JSON.parse(fs.readFileSync(metaPath, "utf8"));
    if (!meta.properties) return null;
    const props = {};
    for (const key of META_PROPERTIES) {
      if (meta.properties[key] !== undefined) {
        props[key] = meta.properties[key];
      }
    }
    return Object.keys(props).length > 0 ? props : null;
  } catch {
    return null;
  }
}

function writeMetaProperties(filePath, properties) {
  const metaPath = getMetaPath(filePath);
  const filtered = {};
  for (const key of META_PROPERTIES) {
    if (properties[key] !== undefined) {
      filtered[key] = properties[key];
    }
  }
  if (Object.keys(filtered).length === 0) {
    if (fs.existsSync(metaPath)) fs.unlinkSync(metaPath);
    return;
  }
  fs.writeFileSync(metaPath, JSON.stringify({ properties: filtered }, null, 2));
}

module.exports = {
  SCRIPT_EXTENSIONS,
  EXTENSION_TO_CLASS,
  getScriptExtension,
  getScriptClassFromFile,
  stripScriptExtension,
  isScriptClass,
  loadProject,
  saveProject,
  ensureDir,
  sanitizeFileName,
  getMetaPath,
  readMetaProperties,
  writeMetaProperties,
  META_PROPERTIES,
};

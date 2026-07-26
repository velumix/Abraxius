const fs = require("fs");
const path = require("path");
const os = require("os");
const { buildPluginSource } = require("./build-plugin");

function pluginsDir() {
  if (process.platform === "win32") {
    return path.join(os.homedir(), "AppData", "Local", "Roblox", "Plugins");
  }
  return path.join(os.homedir(), "Documents", "Roblox", "Plugins");
}

const pluginDir = path.join(__dirname, "..", "plugin", "AbraxiusCompanion");
const initFile = path.join(pluginDir, "init.server.luau");
const destDir = pluginsDir();
const destFile = path.join(destDir, "AbraxiusCompanion.lua");
const legacyFolder = path.join(destDir, "AbraxiusCompanion");

if (!fs.existsSync(initFile)) {
  console.error("Plugin source not found:", initFile);
  process.exit(1);
}

if (!fs.existsSync(destDir)) {
  fs.mkdirSync(destDir, { recursive: true });
}

if (fs.existsSync(legacyFolder)) {
  fs.rmSync(legacyFolder, { recursive: true, force: true });
  console.log(`Removed legacy folder install:\n  ${legacyFolder}`);
}

const initSource = buildPluginSource();

fs.writeFileSync(destFile, initSource);
console.log(`Installed AbraxiusCompanion plugin to:\n  ${destFile}`);
console.log("Restart Roblox Studio to load it.");

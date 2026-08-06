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

function vinegarPluginsDir() {
  if (process.platform === "win32") return null;
  const root = process.env.XDG_DATA_HOME
    ? path.join(process.env.XDG_DATA_HOME, "vinegar")
    : path.join(os.homedir(), ".var", "app", "org.vinegarhq.Vinegar", "data", "vinegar");
  return path.join(root, "prefixes", "studio", "drive_c", "users", os.userInfo().username, "AppData", "Local", "Roblox", "Plugins");
}

const pluginDir = path.join(__dirname, "..", "plugin", "AbraxiusCompanion");
const initFile = path.join(pluginDir, "init.server.luau");
const destinations = [pluginsDir(), vinegarPluginsDir()].filter(Boolean);

if (!fs.existsSync(initFile)) {
  console.error("Plugin source not found:", initFile);
  process.exit(1);
}

const initSource = buildPluginSource();
for (const destDir of destinations) {
  const destFile = path.join(destDir, "AbraxiusCompanion.lua");
  const legacyFolder = path.join(destDir, "AbraxiusCompanion");
  if (!fs.existsSync(destDir)) fs.mkdirSync(destDir, { recursive: true });
  if (fs.existsSync(legacyFolder)) fs.rmSync(legacyFolder, { recursive: true, force: true });
  fs.writeFileSync(destFile, initSource);
  console.log(`Installed AbraxiusCompanion plugin to:\n  ${destFile}`);
}
console.log("Restart Roblox Studio to load it.");

const fs = require("fs");
const path = require("path");
const os = require("os");

function pluginsDir() {
  if (process.platform === "win32") {
    return path.join(os.homedir(), "AppData", "Local", "Roblox", "Plugins");
  }
  return path.join(os.homedir(), "Documents", "Roblox", "Plugins");
}

const pluginDir = path.join(__dirname, "..", "plugin", "AbraxiusCompanion");
const initFile = path.join(pluginDir, "init.server.luau");
const loggerFile = path.join(pluginDir, "Logger.luau");
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

let initSource = fs.readFileSync(initFile, "utf8");

if (fs.existsSync(loggerFile)) {
  let loggerSource = fs.readFileSync(loggerFile, "utf8");
  loggerSource = loggerSource
    .replace(/^--!strict\n?/, "")
    .replace(/^--.*\n/, "")
    .replace(/^--.*\n/, "")
    .replace(/\nreturn Logger\s*$/, "\n");
  initSource = initSource.replace(
    "local Logger = require(script.Logger)",
    loggerSource.trim()
  );
}

fs.writeFileSync(destFile, initSource);
console.log(`Installed AbraxiusCompanion plugin to:\n  ${destFile}`);
console.log("Restart Roblox Studio to load it.");

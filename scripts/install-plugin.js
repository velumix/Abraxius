const fs = require("fs");
const path = require("path");
const os = require("os");

function pluginsDir() {
  if (process.platform === "win32") {
    return path.join(os.homedir(), "AppData", "Local", "Roblox", "Plugins");
  }
  return path.join(os.homedir(), "Documents", "Roblox", "Plugins");
}

const src = path.join(
  __dirname,
  "..",
  "plugin",
  "AbraxiusCompanion",
  "init.server.luau",
);
const destDir = pluginsDir();
const dest = path.join(destDir, "AbraxiusCompanion.lua");
const legacyFolder = path.join(destDir, "AbraxiusCompanion");

if (!fs.existsSync(src)) {
  console.error("Plugin source not found:", src);
  process.exit(1);
}

if (!fs.existsSync(destDir)) {
  fs.mkdirSync(destDir, { recursive: true });
}

if (fs.existsSync(legacyFolder) && fs.statSync(legacyFolder).isDirectory()) {
  fs.rmSync(legacyFolder, { recursive: true, force: true });
  console.log(`Removed legacy folder install:\n  ${legacyFolder}`);
}

fs.copyFileSync(src, dest);
console.log(`Installed AbraxiusCompanion plugin to:\n  ${dest}`);
console.log("Restart Roblox Studio to load it.");

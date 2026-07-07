const fs = require("fs");
const path = require("path");
const os = require("os");

function pluginsDir() {
  if (process.platform === "win32") {
    return path.join(os.homedir(), "AppData", "Local", "Roblox", "Plugins");
  }
  return path.join(os.homedir(), "Documents", "Roblox", "Plugins");
}

const src = path.join(__dirname, "..", "plugin", "AbraxiusCompanion");
const dest = path.join(pluginsDir(), "AbraxiusCompanion");

if (!fs.existsSync(src)) {
  console.error("Plugin source not found:", src);
  process.exit(1);
}

fs.cpSync(src, dest, { recursive: true, force: true });
console.log(`Installed AbraxiusCompanion plugin to:\n  ${dest}`);
console.log("Restart Roblox Studio to load it.");

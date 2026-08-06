"use strict";
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

test("agent profiles separate repository and Studio toolboxes", () => {
  const root = path.join(__dirname, "..");
  const config = JSON.parse(fs.readFileSync(path.join(root, ".abraxius/agent-profiles.json"), "utf8"));
  const developer = config.profiles["abraxius-developer"];
  const studio = config.profiles["roblox-studio"];
  assert.ok(developer.capabilities.includes("filesystem.write"));
  assert.ok(developer.capabilities.includes("shell.execute"));
  assert.ok(developer.capabilities.includes("git.commit"));
  assert.equal(studio.shell, false);
  assert.equal(studio.git, false);
  assert.equal(config.defaultProfile, "abraxius-developer");
});

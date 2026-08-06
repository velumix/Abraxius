const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");

test("Node CLI is a thin client of the app-owned host", () => {
  const source = fs.readFileSync(path.join(root, "cli.js"), "utf8");
  assert.doesNotMatch(source, /require\(["']child_process["']\)/);
  assert.doesNotMatch(source, /server\.js.*--daemon/s);
  assert.doesNotMatch(source, /\.shutdown\(\)/);
  assert.match(source, /Host lifecycle belongs to the app/);
});

test("Rust CLI cannot spawn or stop the app-owned host", () => {
  const source = fs.readFileSync(
    path.join(root, "rust", "abraxius-rs", "src", "main.rs"),
    "utf8",
  );
  assert.doesNotMatch(source, /Command::new\("node"\)/);
  assert.doesNotMatch(source, /"\/shutdown"/);
  assert.match(source, /Host lifecycle belongs to the/);
});

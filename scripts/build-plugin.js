const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..", "plugin", "AbraxiusCompanion");
const entry = path.join(root, "init.server.luau");
const output = path.join(root, "dist", "AbraxiusCompanion.lua");

function stripStrict(source) {
  return source.replace(/^--!strict\r?\n/, "");
}

function inlineModule(source, relativePath, name) {
  const modulePath = path.resolve(root, relativePath);
  if (!modulePath.startsWith(root + path.sep)) throw new Error(`Module escapes plugin root: ${relativePath}`);
  if (!fs.existsSync(modulePath)) throw new Error(`Plugin module not found: ${relativePath}`);
  return `local ${name} = (function()\n${stripStrict(fs.readFileSync(modulePath, "utf8")).trim()}\nend)()`;
}

function buildPluginSource() {
  let source = fs.readFileSync(entry, "utf8");
  source = source.replace(/^--#include\s+(.+?)\s+as\s+(\w+)\s*$/gm, (_, relativePath, name) => inlineModule(source, relativePath.trim(), name));
  const loggerPath = path.join(root, "Logger.luau");
  if (fs.existsSync(loggerPath)) {
    const logger = stripStrict(fs.readFileSync(loggerPath, "utf8")).replace(/\nreturn Logger\s*$/, "\n").trim();
    source = source.replace("local Logger = require(script.Logger)", logger);
  }
  if (/^--#include/m.test(source) || source.includes("require(script.Logger)")) throw new Error("Plugin bundle contains unresolved local dependencies");
  return source;
}

function writePluginBundle() {
  fs.mkdirSync(path.dirname(output), { recursive: true });
  const source = buildPluginSource();
  fs.writeFileSync(output, source);
  return { output, bytes: Buffer.byteLength(source) };
}

if (require.main === module) {
  const result = writePluginBundle();
  console.log(`Built plugin bundle (${result.bytes} bytes):\n  ${result.output}`);
}

module.exports = { buildPluginSource, writePluginBundle, output };

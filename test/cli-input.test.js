const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { Readable } = require("node:stream");
const test = require("node:test");

const {
  readJsonArgument,
  readJsonObjectArgument,
  readTextArgument,
} = require("../lib/cli-input");
const { parseOptions } = require("../cli");

test("JSON files bypass shell escaping and preserve complex Studio payloads", async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "abraxius-input-"));
  const file = path.join(directory, "command.json");
  const expected = {
    path: "game.ServerScriptService.Sword Controller",
    source: "local label = \"Right Arm\\\\IK\"\nprint(label, '⚔️')\n",
    properties: { note: "apostrophe's and `backticks` and $variables" },
  };
  fs.writeFileSync(file, `\ufeff${JSON.stringify(expected)}`, "utf8");

  assert.deepEqual(await readJsonArgument(["--json-file", file]), expected);
});

test("JSON stdin preserves multiline text, quotes, backslashes, and Unicode", async () => {
  const expected = {
    code: "print(\"C:\\\\Roblox\\\\Sword\")\nprint('右腕')",
    confirm: true,
  };
  const stdin = Readable.from([Buffer.from(JSON.stringify(expected), "utf8")]);

  assert.deepEqual(await readJsonArgument(["--json-stdin"], { stdin }), expected);
});

test("text files and stdin preserve Luau byte content without argument joining", async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "abraxius-luau-"));
  const file = path.join(directory, "probe.luau");
  const luau = "local message = [[a \\\\ path, $value, and `tick`]]\nprint(message)\n";
  fs.writeFileSync(file, luau, "utf8");

  assert.equal(await readTextArgument(["--file", file]), luau);
  assert.equal(
    await readTextArgument(["--stdin"], { stdin: Readable.from([luau]) }),
    luau,
  );
});

test("input parser rejects ambiguous sources and explains the PowerShell-safe path", async () => {
  await assert.rejects(
    readJsonArgument(["--json-file", "payload.json", "--json-stdin"]),
    /Choose only one/,
  );
  await assert.rejects(
    readJsonArgument(["{broken json}"]),
    /PowerShell users should prefer --json-file or --json-stdin/,
  );
  await assert.rejects(
    readJsonObjectArgument(["[]"]),
    /must be an object/,
  );
});

test("parseOptions validates boundary flags and rejects missing option values", () => {
  const valid = parseOptions(["--project", "./my-project", "--tag", "tag1", "--tag", "tag2", "--path", "game.Workspace", "--json", "extra"]);
  assert.equal(valid.projectDir, "./my-project");
  assert.deepEqual(valid.tags, ["tag1", "tag2"]);
  assert.equal(valid.path, "game.Workspace");
  assert.equal(valid.json, true);
  assert.deepEqual(valid._, ["extra"]);

  assert.throws(() => parseOptions(["--project"]), /Missing value after --project/);
  assert.throws(() => parseOptions(["--tag"]), /Missing value after --tag/);
  assert.throws(() => parseOptions(["--path"]), /Missing value after --path/);
  assert.throws(() => parseOptions(["--unknown-flag"]), /Unknown option: --unknown-flag/);
});


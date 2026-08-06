const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const { AXL_VERSION, AxlError, parseAxl } = require("../lib/axl");
const fixture = require("./fixtures/axl-conformance.json");
const pluginSource = fs.readFileSync(
  path.join(__dirname, "..", "plugin", "AbraxiusCompanion", "modules", "AXL.luau"),
  "utf8",
);

test("AXL/1 shared conformance examples stay valid in the host parser", () => {
  assert.equal(AXL_VERSION, fixture.version);
  for (const example of fixture.valid) {
    assert.equal(parseAxl(example.source).type, example.type, example.name);
  }
});

test("AXL/1 shared invalid examples retain their compact error classes", () => {
  for (const example of fixture.invalid) {
    assert.throws(
      () => parseAxl(example.source),
      (error) => error instanceof AxlError && error.code === example.code,
      example.name,
    );
  }
});

test("Studio parser exposes every verb in the shared AXL/1 contract", () => {
  for (const verb of fixture.productionVerbs) {
    assert.match(pluginSource, new RegExp(`command == "${verb}"`), verb);
  }
  assert.match(pluginSource, /ERR UNSUPPORTED Operation-owned undo/);
  assert.match(pluginSource, /UNSUPPORTED execute mode must be Edit/);
  assert.match(pluginSource, /NONAMESPACE No namespace entry/);
});

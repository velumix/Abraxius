const assert = require("node:assert/strict");
const test = require("node:test");
const studioLogger = require("../lib/studio-logger");

test("Studio logging uses one emoji and no category labels", () => {
  assert.equal(studioLogger.format("http", "GET status"), "🌐 GET status");
  assert.equal(studioLogger.format("studio", "Tool call: inspect"), "🎮 Tool call: inspect");
  assert.equal(studioLogger.format("studio", "⚡ Call inspect"), "⚡ Call inspect");
  assert.doesNotMatch(studioLogger.format("plugin", "Companion ready"), /PLUGIN|Abraxius|│/);
});

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const source = fs.readFileSync(
  path.join(__dirname, "..", "app", "Abraxius.App", "MainWindow.xaml.cs"),
  "utf8",
);

test("AI research is bounded and exposes only read-only AXL operations", () => {
  const start = source.indexOf("private async Task<AiResearchResult> RunAiResearchAsync");
  const end = source.indexOf("private async Task ResolveAiProjectAsync", start);
  assert.ok(start >= 0 && end > start);
  const research = source.slice(start, end);

  assert.match(research, /const int maximumRounds = 2;/);
  assert.match(research, /const int maximumCalls = 6;/);
  assert.match(research, /const int maximumEvidenceCharacters = 8000;/);
  assert.match(research, /"enum": \["find", "symbols", "lines", "state"\]/);
  assert.match(research, /end = Math\.Min\(end, start \+ 119\);/);
  assert.doesNotMatch(research, /case "(?:patch|execute|undo|source|full)"/);
  assert.doesNotMatch(research, /source = "(?:patch|execute|undo)\b/);
});

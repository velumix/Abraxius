const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("fs");
const path = require("path");
const os = require("os");

const { MemoryOrchestrator } = require("../lib/memory");

function createTestDir() {
  const dir = path.join(os.tmpdir(), `abraxius-mem-integ-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`);
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

test("Abraxius Memory Core Integration: Multi-project, Cloud Isolation & MCP Endpoint", async () => {
  const tmpDir = createTestDir();
  const orchestrator = new MemoryOrchestrator({ baseDir: tmpDir });
  orchestrator.updateSettings({ mcpPort: 8769 });
  await orchestrator.start();

  // 1. Seed Memories
  // Project Alpha Fact
  orchestrator.store.addRecord({
    scope: "project",
    projectId: "alpha",
    type: "project_fact",
    summary: "Alpha service runs on Node.js v22",
    content: "Alpha service is built with Node.js version 22",
  });

  // Project Beta Fact
  orchestrator.store.addRecord({
    scope: "project",
    projectId: "beta",
    type: "project_fact",
    summary: "Beta service runs on Python 3.12",
    content: "Beta service backend uses Python 3.12 with FastAPI",
  });

  // Private Fact
  orchestrator.store.addRecord({
    scope: "private",
    sensitivity: "private",
    summary: "Internal security secret policy",
    content: "Internal security tokens expire in 15 minutes",
  });

  // 2. Integration Test: Project Alpha recall (Project Beta MUST be isolated)
  const recallAlpha = await orchestrator.searchMemories({
    query: "service backend",
    scopeContext: { projectId: "alpha" },
    isLocalModel: true,
  });

  assert.equal(recallAlpha.records.some((r) => r.summary.includes("Alpha service")), true);
  assert.equal(recallAlpha.records.some((r) => r.summary.includes("Beta service")), false);

  // 3. Integration Test: Cloud model model selection (Private MUST be excluded)
  const recallCloud = await orchestrator.searchMemories({
    query: "security tokens",
    scopeContext: { projectId: "alpha" },
    isLocalModel: false, // Cloud model!
  });

  assert.equal(recallCloud.records.some((r) => r.summary.includes("Internal security")), false);

  // 4. Integration Test: External MCP Client HTTP Call to memory_search
  const response = await fetch("http://127.0.0.1:8769/mcp", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "tools/call",
      params: {
        name: "memory_search",
        arguments: {
          query: "Alpha service",
          projectId: "alpha",
        },
      },
    }),
  });

  assert.equal(response.ok, true);
  const mcpData = await response.json();
  assert.equal(mcpData.jsonrpc, "2.0");
  assert.equal(mcpData.result.content[0].type, "text");
  const parsedText = JSON.parse(mcpData.result.content[0].text);
  assert.equal(parsedText.count > 0, true);
  assert.equal(parsedText.records[0].summary.includes("Alpha service"), true);

  await orchestrator.stop();
  fs.rmSync(tmpDir, { recursive: true, force: true });
});

test("Abraxius Memory Core Integration: Post-task Extraction & Review Queue", async () => {
  const tmpDir = createTestDir();
  const orchestrator = new MemoryOrchestrator({ baseDir: tmpDir });

  // Simulate Transcript
  const transcript = `
Developer: decision: Switch database from SQLite to PostgreSQL for production scaling.
Developer: fix: Resolved memory leak by closing idle database connections in connection pool.
  `;

  const extractRes = await orchestrator.extractTaskMemories(transcript, { projectId: "proj-extract" });

  assert.equal(extractRes.proposed.length >= 2, true);

  const proposedQueue = orchestrator.extraction.getProposed("proj-extract");
  assert.equal(proposedQueue.length >= 2, true);

  // Approve first proposed item
  const itemToApprove = proposedQueue[0];
  const approved = orchestrator.extraction.approveProposed(itemToApprove.id);
  assert.equal(approved.verificationStatus, "verified");

  // Correct second item
  const itemToCorrect = proposedQueue[1];
  const corrected = orchestrator.extraction.correctProposed(
    itemToCorrect.id,
    "Corrected memory content: memory leak fixed by connection pool tuning",
    "Corrected fix note",
    "User refinement"
  );

  assert.equal(corrected.newRecord.verificationStatus, "verified");
  assert.equal(corrected.oldRecord.verificationStatus, "superseded");

  fs.rmSync(tmpDir, { recursive: true, force: true });
});

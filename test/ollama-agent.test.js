const test = require("node:test");
const assert = require("node:assert/strict");
const { extractToolRequests, runOllamaAgent } = require("../lib/ollama-agent");

test("Ollama agent parses nested tool arguments", () => {
  const requests = extractToolRequests('ABRAXIUS_TOOL {"name":"multi_edit","arguments":{"edits":[{"old_string":"a","new_string":"{b}"}]}}');
  assert.equal(requests.length, 1);
  assert.equal(requests[0].name, "multi_edit");
  assert.equal(requests[0].arguments.edits[0].new_string, "{b}");
});

test("Ollama agent iterates through tool evidence and reaches success", async () => {
  let calls = 0;
  const responses = [
    'ABRAXIUS_TOOL {"name":"get_studio_state","arguments":{}}',
    "STATUS: SUCCESS\nVerified against the returned Studio state.",
  ];
  const client = { streamChat: async ({ onChunk }) => { const fullText = responses[calls++]; onChunk(fullText); return { fullText }; } };
  const result = await runOllamaAgent({ client, model: "test", prompt: "inspect", callTool: async () => ({ mode: "Edit" }), maxIterations: 3 });
  assert.equal(calls, 2);
  assert.match(result.text, /STATUS: SUCCESS/);
  assert.equal(result.history.length, 1);
});

test("Ollama agent blocks mutations unless explicitly allowed", async () => {
  const client = { streamChat: async ({ onChunk }) => { const text = 'ABRAXIUS_TOOL {"name":"multi_edit","arguments":{"file_path":"x","edits":[]}}'; onChunk(text); return { fullText: text }; } };
  let called = false;
  const result = await runOllamaAgent({ client, model: "test", prompt: "edit", callTool: async () => { called = true; }, maxIterations: 1 });
  assert.equal(called, false);
  assert.equal(result.history[0].result.approvalRequired, true);
});

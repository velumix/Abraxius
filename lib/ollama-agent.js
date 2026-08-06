"use strict";

const MAX_TOOL_RESULT = 6000;

function extractJsonObjects(text) {
  const objects = [];
  const source = String(text || "");
  let start = -1; let depth = 0; let quoted = false; let escaped = false;
  for (let index = 0; index < source.length; index++) {
    const char = source[index];
    if (quoted) { if (escaped) escaped = false; else if (char === "\\") escaped = true; else if (char === '"') quoted = false; continue; }
    if (char === '"') { quoted = true; continue; }
    if (char === "{" && depth === 0) start = index;
    if (char === "{" && start >= 0) depth++;
    if (char === "}" && depth > 0) depth--;
    if (start >= 0 && depth === 0) { objects.push(source.slice(start, index + 1)); start = -1; }
  }
  return objects;
}

function extractToolRequests(text) {
  const requests = [];
  const source = String(text || "");
  for (const marker of source.split(/ABRAXIUS_TOOL\s+/i).slice(1)) {
    try {
      const request = JSON.parse(extractJsonObjects(marker)[0]);
      if (request?.name && request.arguments && typeof request.arguments === "object") requests.push(request);
    } catch {
      // Models occasionally emit a partial marker while streaming; the next round can repair it.
    }
  }
  return requests;
}

function compactResult(value) {
  const raw = typeof value === "string" ? value : JSON.stringify(value);
  return raw.length <= MAX_TOOL_RESULT ? raw : `${raw.slice(0, MAX_TOOL_RESULT)}\n[tool result truncated]`;
}

function isMutation(name) {
  return new Set(["multi_edit", "edit_script", "execute_luau", "push", "find_replace", "batch"]).has(name);
}

/**
 * Run a bounded Ollama/tool/verifier loop. The caller owns policy and supplies
 * callTool so this module is usable by both the Electron UI and the daemon.
 */
async function runOllamaAgent(options = {}) {
  const { client, model, prompt, context = "", callTool, endpoint, temperature = 0.2, numCtx = 16384,
    maxIterations = 5, allowMutations = false, signal, onChunk, onIteration } = options;
  if (!client || !model || !prompt || typeof callTool !== "function") throw new Error("client, model, prompt, and callTool are required");
  const iterations = Math.max(1, Math.min(10, Number(maxIterations) || 5));
  const messages = [{ role: "system", content: [
    "You are the Ollama interpreter for Abraxius and Roblox Studio.",
    "Work in short verified iterations. Use only ABRAXIUS_TOOL JSON markers when requesting tools.",
    "After every tool result, reassess the task. Never claim success without a concrete verification result.",
    "When blocked, finish with STATUS: MISSING and list the exact missing evidence or permission.",
    "When verified, finish with STATUS: SUCCESS and summarize the checks.",
    "Keep tool requests compact and never request the full hierarchy when a targeted read/search is enough.",
  ].join("\n") }, { role: "user", content: `TASK:\n${prompt}\n\nLIVE ABRAXIUS CONTEXT:\n${context}` }];
  let lastText = "";
  const history = [];

  for (let iteration = 1; iteration <= iterations; iteration++) {
    onIteration?.({ iteration, maxIterations: iterations, phase: "thinking" });
    const chunks = [];
    const result = await client.streamChat({ model, messages, endpoint, temperature, numCtx, signal,
      onChunk: (chunk) => { chunks.push(chunk); onChunk?.({ iteration, chunk }); },
    });
    lastText = result.fullText || chunks.join("");
    messages.push({ role: "assistant", content: lastText });
    const requests = extractToolRequests(lastText);
    if (requests.length === 0) {
      const normalized = lastText.toUpperCase();
      if (/STATUS:\s*(SUCCESS|MISSING)/.test(normalized) || iteration === iterations) break;
      messages.push({ role: "user", content: "Self-evaluate this result. If evidence is missing, emit one precise ABRAXIUS_TOOL request; otherwise finish with STATUS: SUCCESS or STATUS: MISSING." });
      continue;
    }

    for (const request of requests.slice(0, 8)) {
      if (isMutation(request.name) && !allowMutations) {
        const blocked = { approvalRequired: true, name: request.name, reason: "Agent mutations are disabled; enable Allow agent edits." };
        history.push({ iteration, request, result: blocked });
        messages.push({ role: "user", content: `[ABRAXIUS_TOOL_RESULT] ${request.name}: ${compactResult(blocked)}` });
        continue;
      }
      try {
        const toolResult = await callTool(request.name, request.arguments, { approved: allowMutations });
        history.push({ iteration, request, result: toolResult });
        messages.push({ role: "user", content: `[ABRAXIUS_TOOL_RESULT] ${request.name}: ${compactResult(toolResult)}` });
      } catch (error) {
        const failure = { error: error.message };
        history.push({ iteration, request, result: failure });
        messages.push({ role: "user", content: `[ABRAXIUS_TOOL_RESULT] ${request.name}: ${compactResult(failure)}` });
      }
    }
    onIteration?.({ iteration, maxIterations: iterations, phase: "verified", toolCount: requests.length });
  }

  return { ok: true, model, iterations: Math.min(iterations, history.length ? Math.max(...history.map((item) => item.iteration)) : 1), text: lastText, history };
}

module.exports = { extractToolRequests, runOllamaAgent };

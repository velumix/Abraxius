(() => {
  const tauri = window.__TAURI__;
  if (!tauri?.core?.invoke) return;
  const invoke = (name, ...args) => tauri.core.invoke("backend_call", { name, args });
  const listen = (channel, callback) => tauri.event.listen("backend-event", (event) => {
    const payload = event.payload || {};
    if (payload.channel === channel) callback(payload.value);
  });
  const events = (channel, callback) => { listen(channel, callback); };
  const replayEvents = (channel, callback) => {
    const seen = new Set();
    const poll = async () => {
      try {
        const history = await tauri.core.invoke("backend_events", { channel });
        for (const value of history || []) {
          const key = JSON.stringify(value);
          if (seen.has(key)) continue;
          seen.add(key);
          callback(value);
        }
        while (seen.size > 2000) seen.delete(seen.values().next().value);
      } catch {}
    };
    poll();
    setInterval(poll, 350);
  };
  window.abraxius = Object.freeze({
    health: () => invoke("health"), events: (limit) => invoke("events", limit), pending: () => invoke("pending"),
    runCli: (args) => invoke("run-cli", args), restartHost: () => invoke("restart-host"), openLog: () => invoke("open-log"), openData: () => invoke("open-data"),
    getAutostart: () => invoke("autostart-status"), setAutostart: (enabled) => invoke("autostart", enabled),
    antigravity: Object.freeze({
      status: () => invoke("antigravity-status"), start: (options) => invoke("antigravity-start", options), prompt: (prompt, options) => invoke("antigravity-prompt", prompt, options),
      setWriteAccess: (enabled) => invoke("antigravity-permissions", enabled), restart: () => invoke("antigravity-restart"), interrupt: () => invoke("antigravity-interrupt"), resize: (cols, rows) => invoke("antigravity-resize", cols, rows), stop: () => invoke("antigravity-stop"), write: (data) => invoke("antigravity-write", data), onEvent: (callback) => events("antigravity-event", callback),
    }),
    memory: Object.freeze({
      health: () => invoke("memory-health"), search: (query, projectId) => invoke("memory-search", query, projectId), records: (scope, type, projectId, status) => invoke("memory-records", scope, type, projectId, status), add: (data) => invoke("memory-add", data), correct: (payload) => invoke("memory-correct", payload), forget: (id) => invoke("memory-forget", id), proposed: (projectId) => invoke("memory-proposed", projectId), approve: (id) => invoke("memory-approve", id), reject: (id) => invoke("memory-reject", id), brief: (projectId) => invoke("memory-brief", projectId), getSettings: () => invoke("memory-settings-get"), saveSettings: (settings) => invoke("memory-settings-save", settings), indexDir: (dirPath) => invoke("memory-index-dir", dirPath),
    }),
    ollama: Object.freeze({
      status: () => invoke("ollama-status"), models: (endpoint) => invoke("ollama-models", endpoint), pull: (payload) => invoke("ollama-pull", payload), cancelPull: (id) => invoke("ollama-pull-cancel", id), onPullProgress: (callback) => events("ollama-pull-progress", callback), chat: (payload) => invoke("ollama-chat", payload), agent: (payload) => invoke("ollama-agent", payload), cancel: (id) => invoke("ollama-cancel", id), getSettings: () => invoke("ollama-settings-get"), saveSettings: (s) => invoke("ollama-settings-save", s), onChunk: (cb) => events("ollama-chunk", cb), onAgentStatus: (cb) => events("ollama-agent-status", cb), onChatStart: (cb) => events("ollama-chat-start", cb), onResearch: (cb) => events("ollama-research", cb), ptyStatus: () => invoke("ollama-pty-status"), ptyStart: (o) => invoke("ollama-pty-start", o), ptyRestart: (o) => invoke("ollama-pty-restart", o), ptyStop: () => invoke("ollama-pty-stop"), ptyInterrupt: () => invoke("ollama-pty-interrupt"), ptyWrite: (d) => invoke("ollama-pty-write", d), onPtyEvent: (cb) => events("ollama-pty-event", cb),
    }),
    nvidiaNim: Object.freeze({
      status: () => invoke("nvidia-nim-status"), getSettings: () => invoke("nvidia-nim-settings-get"), saveSettings: (s) => invoke("nvidia-nim-settings-save", s), chat: (p) => invoke("nvidia-nim-chat", p), cancel: (id) => invoke("nvidia-nim-cancel", id), onReasoning: (cb) => events("nvidia-nim-reasoning", cb), onChunk: (cb) => events("nvidia-nim-chunk", cb), onChatStart: (cb) => events("nvidia-nim-chat-start", cb), onChatEnd: (cb) => events("nvidia-nim-chat-end", cb),
    }),
    openrouter: Object.freeze({
      status: () => invoke("openrouter-status"), models: (o) => invoke("openrouter-models", o), getSettings: () => invoke("openrouter-settings-get"), saveSettings: (s) => invoke("openrouter-settings-save", s), chat: (p) => invoke("openrouter-chat", p), cancel: (id) => invoke("openrouter-cancel", id), onChunk: (cb) => events("openrouter-chunk", cb), onRetry: (cb) => events("openrouter-retry", cb), onTool: (cb) => events("openrouter-tool", cb), onToolResult: (cb) => events("openrouter-tool-result", cb), approveTool: (id, ok) => invoke("openrouter-tool-approval", id, ok), onToolApproval: (cb) => events("openrouter-tool-approval", cb), onChatStart: (cb) => events("openrouter-chat-start", cb),
    }),
    pty: Object.freeze({
      list: () => invoke("pty-list"), create: (options) => invoke("pty-create", options), write: (id, data) => invoke("pty-write", { id, data }), resize: (id, cols, rows) => invoke("pty-resize", { id, cols, rows }), stop: (id) => invoke("pty-stop", { id }), restart: (id) => invoke("pty-restart", { id }), close: (id) => invoke("pty-close", { id }), getBuffer: (id) => invoke("pty-buffer", { id }), getHistory: () => invoke("pty-history"), onEvent: (cb) => events("pty-event", cb), onActivity: (cb) => events("pty-activity", cb), onActivityUpdate: (cb) => events("pty-activity-update", cb),
    }),
    onHostExit: (callback) => events("host-exit", callback),
  });
})();

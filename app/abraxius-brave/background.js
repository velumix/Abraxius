const API_BASE = "http://127.0.0.1:13470";
const MAX_CONTEXT_CHARS = 24000;
const AI_WS_URL = "ws://127.0.0.1:13473/ai";
let controlSocket = null;
let controlRetry = null;
let autoToolBusy = false;
let autoToolReply = "";
let autoToolKey = "";
let autoProcessingUntil = 0;
let pendingApproval = null;
let yoloMode = false;

chrome.storage.local.get({ abraxiusYoloMode: false }).then((value) => {
  yoloMode = value.abraxiusYoloMode === true;
}).catch(() => {});

function isMutationTool(toolName) {
  return !["get_selection", "inspect_project", "list_tools", "list_files", "read_file", "search_code", "list_directory", "search_files", "git_status", "git_diff", "ollama_chat", "ollama_list_models"].includes(toolName);
}

function extractTargetPath(args = {}) {
  if (!args || typeof args !== "object") return ".";
  return args.path || args.cwd || args.target_file || args.file_path || args.query || args.command || ".";
}

function formatSummary(toolName, result, error) {
  if (error) return error.message || String(error);
  if (!result) return "OK";
  if (typeof result === "string") return result.slice(0, 120);

  if (toolName === "create_file") {
    return `Created file ${result.path || ""} (${result.bytes ?? 0} bytes)`.trim();
  }
  if (toolName === "create_directory") {
    return `Created directory ${result.path || ""}`.trim();
  }
  if (toolName === "apply_patch") {
    if (result.stdout) return result.stdout.trim().split("\n")[0];
    return `Applied patch`;
  }
  if (toolName === "git_diff") {
    const len = typeof result.stdout === "string" ? result.stdout.length : 0;
    return `Diff retrieved (${len} bytes)`;
  }
  if (toolName === "git_status") {
    const len = typeof result.stdout === "string" ? result.stdout.length : 0;
    return `Status retrieved (${len} bytes)`;
  }
  if (toolName === "read_file") {
    const len = typeof result.content === "string" ? result.content.length : 0;
    return `Read file (${len} bytes)`;
  }
  if (toolName === "list_directory" || toolName === "list_files") {
    const count = Array.isArray(result.entries) ? result.entries.length : 0;
    return `Listed directory (${count} entries)`;
  }
  if (toolName === "search_files" || toolName === "search_code") {
    const count = Array.isArray(result.results) ? result.results.length : 0;
    return `Found ${count} matches`;
  }
  if (toolName === "run_command") {
    return `Command finished (exit code ${result.exitCode ?? 0})`;
  }
  if (result.message) return String(result.message);
  if (result.ok) return "Success";

  try {
    const str = JSON.stringify(result);
    return str.length > 120 ? `${str.slice(0, 117)}...` : str;
  } catch {
    return "Completed";
  }
}

function activityStructured({ status = "INFO", tool, target, summary, message, level = "info" } = {}) {
  const at = Date.now();
  const event = { at, status, tool, target, summary, message, level };
  try { chrome.runtime.sendMessage({ type: "ABRAXIUS_ACTIVITY", event }).catch(() => {}); } catch {}
}

function activity(message, level = "info") {
  activityStructured({ message, level });
}

async function api(path, options = {}) {
  const response = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
  });
  const text = await response.text();
  let body;
  try { body = text ? JSON.parse(text) : {}; } catch { body = { raw: text }; }
  if (!response.ok) throw new Error(body.error || `Abraxius returned HTTP ${response.status}`);
  return body;
}

function wsRpc(method, params = {}) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(AI_WS_URL);
    const id = crypto.randomUUID();
    let settled = false;
    const finish = (callback, value) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      callback(value);
    };
    const longRunning = method === "tools/call" && ["ollama_chat", "ollama_pull_model"].includes(params?.name || params?.arguments?.name);
    const timeout = setTimeout(() => { socket.close(); finish(reject, new Error("Abraxius AI tool channel timed out")); }, longRunning ? 600000 : 15000);
    socket.onopen = () => socket.send(JSON.stringify({ id, method, params }));
    socket.onmessage = (event) => {
      let message;
      try { message = JSON.parse(event.data); } catch { return; }
      if (message.id !== id) return;
      socket.close();
      if (message.error) finish(reject, new Error(message.error)); else finish(resolve, message.result);
    };
    socket.onerror = () => finish(reject, new Error("Cannot connect to Abraxius AI tool WebSocket"));
    socket.onclose = () => {
      if (!settled) finish(reject, new Error("Abraxius AI tool channel closed before the result arrived"));
    };
  });
}

function connectControlChannel() {
  if (controlSocket && (controlSocket.readyState === WebSocket.OPEN || controlSocket.readyState === WebSocket.CONNECTING)) return;
  try { controlSocket = new WebSocket(AI_WS_URL); } catch { scheduleControlReconnect(); return; }
  controlSocket.onopen = () => controlSocket.send(JSON.stringify({ id: crypto.randomUUID(), method: "initialize", params: { role: "browser_extension" } }));
  controlSocket.onmessage = async (event) => {
    let message;
    try { message = JSON.parse(event.data); } catch { return; }
    if (message.type !== "browser_command") return;
    try {
      const tab = await activeTab();
      if (!tab?.id) throw new Error("No active browser tab");
      let result;
      if (message.command === "page/get_context") result = await sendToTab(tab.id, { type: "ABRAXIUS_GET_PAGE_CONTEXT" });
      else if (message.command === "page/get_last_reply") result = await sendToTab(tab.id, { type: "ABRAXIUS_GET_LAST_REPLY" });
      else if (message.command === "page/get_reply_state") result = await sendToTab(tab.id, { type: "ABRAXIUS_GET_REPLY_STATE" });
      else if (message.command === "page/wait_for_reply") result = await sendToTab(tab.id, { type: "ABRAXIUS_WAIT_FOR_REPLY", previous: message.payload?.previous, timeoutMs: message.payload?.timeoutMs });
      else if (message.command === "page/insert_context") result = await sendToTab(tab.id, { type: "ABRAXIUS_INSERT_CONTEXT", context: String(message.payload?.context || "").slice(0, MAX_CONTEXT_CHARS) });
      else if (message.command === "page/submit") result = await sendToTab(tab.id, { type: "ABRAXIUS_SUBMIT" });
      else throw new Error(`Unknown browser command: ${message.command}`);
      controlSocket?.send(JSON.stringify({ type: "browser_result", id: message.id, result }));
    } catch (error) { controlSocket?.send(JSON.stringify({ type: "browser_result", id: message.id, error: error.message })); }
  };
  controlSocket.onclose = () => { controlSocket = null; scheduleControlReconnect(); };
  controlSocket.onerror = () => {};
}

function scheduleControlReconnect() {
  if (controlRetry) return;
  controlRetry = setTimeout(() => { controlRetry = null; connectControlChannel(); }, 2000);
}

async function activeTab() {
  const tabs = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
  return tabs.find((tab) => /^https?:\/\//i.test(tab.url || "")) || tabs[0];
}

async function sendToTab(tabId, message) {
  try {
    return await chrome.tabs.sendMessage(tabId, message);
  } catch (firstError) {
    try {
      await chrome.scripting.executeScript({ target: { tabId }, files: ["content.js"] });
      return await chrome.tabs.sendMessage(tabId, message);
    } catch (secondError) {
      throw new Error(`Cannot reach chatbot page: ${secondError.message || firstError.message}`);
    }
  }
}

function latestToolRequest(reply) {
  const source = String(reply || "");
  const markers = [...source.matchAll(/(?:ABRAXIUS_TOOL|abraxius_tool)\s*/gi)];
  const marker = markers.at(-1);
  if (!marker) return null;
  const start = source.indexOf("{", marker.index + marker[0].length);
  if (start < 0) return null;
  let depth = 0; let quoted = false; let escaped = false;
  for (let index = start; index < source.length; index++) {
    const char = source[index];
    if (quoted) { if (escaped) escaped = false; else if (char === "\\") escaped = true; else if (char === '"') quoted = false; continue; }
    if (char === '"') { quoted = true; continue; }
    if (char === "{") depth++;
    if (char === "}") depth--;
    if (depth === 0) { try { return JSON.parse(source.slice(start, index + 1)); } catch { return null; } }
  }
  return null;
}

async function autonomousToolTick() {
  if (autoToolBusy) return;
  autoToolBusy = true;
  let tab = null;
  let request = null;
  try {
    tab = await activeTab();
    if (!tab?.id || !/^https?:\/\//i.test(tab.url || "")) return;
    const latest = await sendToTab(tab.id, { type: "ABRAXIUS_GET_LAST_REPLY" });
    const reply = String(latest?.reply || "");
    if (!reply || reply === autoToolReply) return;
    request = latestToolRequest(reply);
    if (!request?.name || !request.arguments || request.name === "multi_edit" || request.name === "edit_script" || request.name === "execute_luau" || request.name === "push" || request.name === "find_replace" || request.name === "batch") return;
    const requestKey = `${request.name}:${JSON.stringify(request.arguments)}`;
    if (requestKey === autoToolKey) return;

    const targetPath = extractTargetPath(request.arguments);
    const knownReadOnly = ["get_selection", "inspect_project", "list_tools", "list_files", "read_file", "search_code", "list_directory", "search_files", "git_status", "git_diff", "ollama_chat", "ollama_list_models"];
    let autonomous = knownReadOnly.includes(request.name);
    if (!autonomous) {
      const catalog = await wsRpc("tools/list").catch(() => ({ tools: [] }));
      const definition = (catalog?.tools || []).find((tool) => tool.name === request.name);
      autonomous = definition?.annotations?.readOnlyHint === true;
    }

    if (!autonomous && !(yoloMode && isMutationTool(request.name))) {
      autoToolKey = requestKey;
      autoToolReply = reply;
      pendingApproval = { request, reply, tabId: tab.id, key: requestKey, at: Date.now() };
      activityStructured({ status: "APPROVAL_REQUIRED", tool: request.name, target: targetPath, summary: "Requires approval in Abraxius side panel" }, "warn");
      try { chrome.runtime.sendMessage({ type: "ABRAXIUS_APPROVAL_REQUEST", request }).catch(() => {}); } catch {}
      return;
    }

    autoToolKey = requestKey;
    autoToolReply = reply;
    activityStructured({ status: "DISPATCHED", tool: request.name, target: targetPath }, "info");
    const result = await wsRpc("tools/call", { name: request.name, arguments: request.arguments, approved: true });
    const summary = formatSummary(request.name, result);
    activityStructured({ status: "SUCCESS", tool: request.name, target: targetPath, summary }, "success");

    const callId = request.id || `call-${Date.now()}`;
    await sendToolResultAndSubmit(tab.id, { id: callId, tool: request.name, ok: true, result });
  } catch (error) {
    const targetPath = request ? extractTargetPath(request.arguments) : ".";
    const toolName = request?.name || "tool";
    activityStructured({ status: "ERROR", tool: toolName, target: targetPath, summary: error.message || String(error) }, "error");
    autoToolKey = "";
    if (tab?.id && request?.name) {
      const callId = request.id || `call-${Date.now()}`;
      const delivered = await sendToolResultAndSubmit(tab.id, { id: callId, tool: request.name, ok: false, error: error.message || String(error) }).then(() => true).catch(() => false);
      // If the page could not accept the failure result, allow the next tick
      // to retry after the control channel/page has recovered.
      if (!delivered) autoToolReply = "";
    }
  } finally { autoToolBusy = false; }
}

async function sendToolResultAndSubmit(tabId, payload) {
  const context = `[ABRAXIUS_TOOL_RESULT]\n${JSON.stringify(payload, null, 2)}\n[/ABRAXIUS_TOOL_RESULT]`;
  const response = await sendToTab(tabId, { type: "ABRAXIUS_INSERT_AND_SUBMIT", context });
  if (response?.error) throw new Error(response.error);
  return response;
}

async function buildAbraxiusSkill(command = "") {
  const catalog = await wsRpc("tools/list").catch(() => ({ tools: [] }));
  const tools = (catalog.tools || []).map((tool) => tool.name).filter(Boolean).join(", ");
  return `[ABRAXIUS ACTIVE] Local bridge connected. Available tools: ${tools || "request tools/list"}. Emit exactly one valid JSON marker when needed: ABRAXIUS_TOOL {"name":"tool_name","arguments":{}}. Escape inner quotes with backslashes; never use shell chains (&&). Mutating tools require ${yoloMode ? "no additional approval because YOLO mode is enabled" : "approval in the Abraxius side panel"}. Wait for ABRAXIUS_TOOL_RESULT, verify results, and never claim an action ran without one. Task: ${String(command).trim() || "Ask what Abraxius/Studio task to perform."}`;
}

async function pageContext() {
  const tab = await activeTab();
  if (!tab?.id) return { title: "", url: "", selection: "", text: "" };
  try {
    return await sendToTab(tab.id, { type: "ABRAXIUS_GET_PAGE_CONTEXT" });
  } catch (error) {
    return { title: tab.title || "", url: tab.url || "", selection: "", text: "", error: error.message };
  }
}

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({ id: "abraxius-send-selection", title: "Send selection to Abraxius", contexts: ["selection"] });
});

connectControlChannel();
setInterval(() => {
  if (Date.now() < autoProcessingUntil) autonomousToolTick();
}, 3000);

chrome.alarms.create("abraxius-control-keepalive", { periodInMinutes: 0.4 });
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === "abraxius-control-keepalive") connectControlChannel();
});

chrome.action.onClicked.addListener(() => chrome.sidePanel.open({ windowId: chrome.windows.WINDOW_ID_CURRENT }));

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  (async () => {
    if (message.type === "ABRAXIUS_SLASH_SKILL") {
      autoProcessingUntil = Date.now() + 10 * 60 * 1000;
      autoToolReply = "";
      autoToolKey = "";
      return { skill: await buildAbraxiusSkill(message.command || "") };
    }
    if (message.type === "ABRAXIUS_AUTO_PROCESS") {
      autoProcessingUntil = Math.max(autoProcessingUntil, Date.now() + 2 * 60 * 1000);
      await autonomousToolTick();
      return { ok: true };
    }
    if (message.type === "ABRAXIUS_GET_PERMISSION_MODE") return { yolo: yoloMode };
    if (message.type === "ABRAXIUS_SET_PERMISSION_MODE") {
      yoloMode = message.yolo === true;
      await chrome.storage.local.set({ abraxiusYoloMode: yoloMode });
      activityStructured({ status: "PERMISSION_MODE", summary: yoloMode ? "YOLO enabled: mutating tools auto-approved" : "Approval required for mutating tools" });
      return { yolo: yoloMode };
    }
    if (message.type === "ABRAXIUS_GET_PENDING_APPROVAL") {
      return { request: pendingApproval?.request || null };
    }
    if (message.type === "ABRAXIUS_DENY_APPROVAL") {
      if (pendingApproval?.request) {
        const req = pendingApproval.request;
        const targetPath = extractTargetPath(req.arguments);
        activityStructured({ status: "DENIED", tool: req.name, target: targetPath, summary: "Tool execution denied by user" }, "warn");
        if (pendingApproval.tabId) {
          const callId = req.id || `call-${Date.now()}`;
          await sendToolResultAndSubmit(pendingApproval.tabId, { id: callId, tool: req.name, ok: false, error: "Tool execution denied by user" }).catch(() => {});
        }
        pendingApproval = null;
      }
      return { ok: true };
    }
    if (message.type === "ABRAXIUS_PAGE_CONTEXT") return pageContext();
    if (message.type === "ABRAXIUS_GET_LAST_REPLY") {
      const tab = await activeTab();
      if (!tab?.id) throw new Error("No active tab");
      return sendToTab(tab.id, { type: "ABRAXIUS_GET_LAST_REPLY" });
    }
    if (message.type === "ABRAXIUS_HEALTH") return api("/health");
    if (message.type === "ABRAXIUS_TOOLS") return wsRpc("tools/list");
    if (message.type === "ABRAXIUS_AI_CONTEXT") {
      return wsRpc("context/get", { projectDir: message.projectDir });
    }
    if (message.type === "ABRAXIUS_CALL") {
      if (!message.name || typeof message.arguments !== "object") throw new Error("Invalid tool request");
      const targetPath = extractTargetPath(message.arguments);
      activityStructured({ status: "DISPATCHED", tool: message.name, target: targetPath }, "info");
      try {
        const result = await wsRpc("tools/call", { name: message.name, arguments: message.arguments, approved: Boolean(message.approved) });
        const summary = formatSummary(message.name, result);
        activityStructured({ status: "SUCCESS", tool: message.name, target: targetPath, summary }, "success");
        if (pendingApproval && pendingApproval.request?.name === message.name) {
          pendingApproval = null;
        }
        return result;
      } catch (err) {
        const summary = err.message || String(err);
        activityStructured({ status: "ERROR", tool: message.name, target: targetPath, summary }, "error");
        throw err;
      }
    }
    if (message.type === "ABRAXIUS_INJECT_CONTEXT") {
      const tab = await activeTab();
      if (!tab?.id) throw new Error("No active tab");
      const context = String(message.context || "").slice(0, MAX_CONTEXT_CHARS);
      return sendToTab(tab.id, { type: "ABRAXIUS_INSERT_CONTEXT", context });
    }
    if (message.type === "ABRAXIUS_SUBMIT") {
      const tab = await activeTab();
      if (!tab?.id) throw new Error("No active tab");
      return sendToTab(tab.id, { type: "ABRAXIUS_SUBMIT" });
    }
    throw new Error(`Unknown message type: ${message.type}`);
  })().then(sendResponse, (error) => sendResponse({ error: error.message })).catch(() => {});
  return true;
});

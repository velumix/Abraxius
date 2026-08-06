const $ = (id) => document.getElementById(id);
let page = null;
let studio = "";
let tools = [];
let yoloMode = false;

function show(value) { $("context").textContent = typeof value === "string" ? value : JSON.stringify(value, null, 2); }
function status(text, bad = false) { $("status").textContent = text; $("status").style.color = bad ? "#ff8d8d" : "#aeb7d5"; }

function logActivity(event, defaultLevel = "info") {
  let line = "";
  if (typeof event === "object" && event !== null) {
    const at = event.at ? new Date(event.at) : new Date();
    const timeStr = at.toLocaleTimeString();
    if (event.tool) {
      const parts = [
        `[${timeStr}]`,
        (event.status || event.level || defaultLevel).toUpperCase(),
        `tool=${event.tool}`,
        `target=${event.target || "."}`,
      ];
      if (event.summary) parts.push(`summary=${event.summary}`);
      line = parts.join(" ");
    } else {
      const lvl = (event.level || defaultLevel).toUpperCase();
      line = `[${timeStr}] ${lvl} ${event.message || JSON.stringify(event)}`;
    }
  } else {
    line = `[${new Date().toLocaleTimeString()}] ${defaultLevel.toUpperCase()} ${event}`;
  }
  const node = $("console");
  node.textContent = `${node.textContent === "Waiting for Abraxius activity…" ? "" : `${node.textContent}\n`}${line}`.split("\n").slice(-80).join("\n");
  node.scrollTop = node.scrollHeight;
}

chrome.runtime.onMessage.addListener((message) => {
  if (message.type === "ABRAXIUS_ACTIVITY" && message.event) logActivity(message.event);
  if (message.type === "ABRAXIUS_APPROVAL_REQUEST" && message.request) showApproval(message.request);
});

function showApproval(request) {
  const target = request.arguments?.path || request.arguments?.cwd || request.arguments?.target_file || request.arguments?.file_path || ".";
  $("approval").innerHTML = `<div class="approval"><b>Approval required: ${request.name}</b><br><small style="color: #aeb7d5;">Target: ${target}</small><pre>${JSON.stringify(request.arguments || {}, null, 2)}</pre><button id="approve-live">Approve and run</button><button id="deny-live" class="secondary">Deny</button></div>`;
  $("deny-live").onclick = async () => {
    $("approval").textContent = "Request denied.";
    await send({ type: "ABRAXIUS_DENY_APPROVAL" }).catch(() => {});
  };
  $("approve-live").onclick = async () => {
    $("approve-live").disabled = true;
    try {
      const result = await send({ type: "ABRAXIUS_CALL", name: request.name, arguments: request.arguments, approved: true });
      const callId = request.id || `call-${Date.now()}`;
      await send({ type: "ABRAXIUS_INSERT_AND_SUBMIT", context: `[ABRAXIUS_TOOL_RESULT]\n${JSON.stringify({ id: callId, tool: request.name, ok: true, result }, null, 2)}\n[/ABRAXIUS_TOOL_RESULT]` });
      $("approval").textContent = `Approved and completed: ${request.name}`;
      return result;
    } catch (error) {
      status(error.message, true);
    }
  };
}

async function send(message) {
  const result = await chrome.runtime.sendMessage(message);
  if (result?.error) throw new Error(result.error);
  return result;
}

async function refreshPermissionMode() {
  const mode = await send({ type: "ABRAXIUS_GET_PERMISSION_MODE" }).catch(() => ({ yolo: false }));
  yoloMode = mode?.yolo === true;
  $("yolo").checked = yoloMode;
}

$("yolo").onchange = async () => {
  try {
    const mode = await send({ type: "ABRAXIUS_SET_PERMISSION_MODE", yolo: $("yolo").checked });
    yoloMode = mode.yolo === true;
    status(yoloMode ? "YOLO enabled: mutating tools will run without per-request approval." : "Approval required for mutating tools.");
    if (yoloMode) $("approval").textContent = "YOLO mode enabled.";
  } catch (error) {
    $("yolo").checked = yoloMode;
    status(error.message, true);
  }
};

async function refresh() {
  try {
    logActivity({ message: "Checking page, Studio, and tool connection…", level: "info" });
    const [health, currentPage, context, availableTools, pending] = await Promise.all([
      send({ type: "ABRAXIUS_HEALTH" }),
      send({ type: "ABRAXIUS_PAGE_CONTEXT" }),
      send({ type: "ABRAXIUS_AI_CONTEXT" }),
      send({ type: "ABRAXIUS_TOOLS" }),
      send({ type: "ABRAXIUS_GET_PENDING_APPROVAL" }).catch(() => null),
    ]);
    page = currentPage; studio = typeof context === "string" ? context : JSON.stringify(context, null, 2);
    tools = availableTools?.tools || [];
    show({ page, abraxius: studio, connection: health });
    status(`Abraxius ${health.connected ? "connected to Studio" : "running; Studio disconnected"}`);
    if (pending?.request) showApproval(pending.request);
  } catch (error) {
    logActivity(error.message, "error");
    show({ error: error.message });
    status(`Refresh failed: ${error.message}`, true);
  }
}

$("refresh").onclick = refresh;
$("inject").onclick = async () => {
  try {
    const prompt = $("prompt").value.trim() || "Use this context to help answer my next question.";
    const toolGuide = `\n\n[ABRAXIUS TOOL PROTOCOL]\nYou may request a tool by outputting exactly:\nABRAXIUS_TOOL {"name":"tool_name","arguments":{}}\nThe extension will execute the request and return ABRAXIUS_TOOL_RESULT. Read-only requests are allowed; mutations require explicit approval. Available tools:\n${tools.map((tool) => `- ${tool.name}: ${tool.description || ""}`).join("\n")}`;
    const packet = `${toolGuide}\n\n[ABRAXIUS PAGE CONTEXT]\n${JSON.stringify(page || {}, null, 2)}\n\n[ABRAXIUS STUDIO CONTEXT]\n${studio}\n\n${prompt}`;
    await send({ type: "ABRAXIUS_INJECT_CONTEXT", context: packet });
    status("Context inserted into the chatbot composer.");
  } catch (error) { status(error.message, true); }
};

function parseToolRequest(reply) {
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
    if (depth === 0) {
      try {
        const request = JSON.parse(source.slice(start, index + 1));
        if (!request.name || typeof request.arguments !== "object") return null;
        return request;
      } catch { return null; }
    }
  }
  return null;
}

async function updateReplyProgress() {
  const state = await send({ type: "ABRAXIUS_GET_REPLY_STATE" }).catch(() => null);
  if (state?.transient) status(`ChatGPT progress: ${state.reply || "working"}`);
}

$("tool").onclick = async () => {
  try {
    const latest = await send({ type: "ABRAXIUS_GET_LAST_REPLY" });
    const request = parseToolRequest(latest.reply);
    if (!request) throw new Error("No ABRAXIUS_TOOL request found in the latest chatbot reply.");
    showApproval(request);
  } catch (error) { status(error.message, true); }
};

$("send").onclick = async () => {
  status("Local model chat is available through Abraxius/Ollama; configure a provider before using this action.", true);
};

refreshPermissionMode();
refresh();
setInterval(() => {
  send({ type: "ABRAXIUS_GET_PENDING_APPROVAL" }).then((pending) => {
    if (pending?.request) showApproval(pending.request);
  }).catch(() => {});
  updateReplyProgress();
}, 2500);

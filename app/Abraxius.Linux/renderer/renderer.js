const $ = (id) => document.getElementById(id);
const pageMeta = {
  home: ["Home", "Your Roblox Studio bridge at a glance."],
  activity: ["Activity", "Recent signals reported by the Studio companion."],
  antigravity: ["Antigravity", "Persistent CLI state, clean responses, and live interactive workspace."],
  ollama: ["Ollama", "Local LLM chat workspace powered by Ollama and Abraxius Memory Core."],
  openrouter: ["OpenRouter", "Remote model workspace with privacy-aware Abraxius Memory Core context."],
  "nvidia-nim": ["NVIDIA NIM", "Remote Nemotron workspace with streamed reasoning and answers."],
  sync: ["Sync & Code", "Pull mapped scripts and apply guarded source changes."],
  diagnostics: ["Diagnostics", "Inspect the local host without exposing source code."],
  settings: ["Settings", "Control Linux desktop behavior."],
};
let latestHealth;
let lastAgyStatusError = "";
let agyAutoStartAttempted = false;

function scrubSecrets(rawText) {
  if (typeof rawText !== "string" || !rawText) return rawText;
  return rawText
    .replace(/\b[0-9a-f]{64}\b/gi, "[REDACTED_SECRET_TOKEN]")
    .replace(/(ABRAXIUS_[A-Z0-9_]*|TOKEN|SECRET|API_KEY)=['"]?[A-Za-z0-9_\-\.]{16,}['"]?/gi, "$1=[REDACTED]");
}

const agyTerminal = new Terminal({
  convertEol: true,
  cursorBlink: true,
  cursorStyle: "bar",
  disableStdin: false,
  fontFamily: '"Google Sans Code", monospace',
  fontSize: 14,
  lineHeight: 1.4,
  scrollback: 5000,
  theme: {
    background: "#101418",
    foreground: "#eef2f7",
    cursor: "#f59e0b",
    cursorAccent: "#101418",
    selectionBackground: "rgba(245, 158, 11, 0.25)",
    black: "#171c22",
    red: "#f97316",
    green: "#22c55e",
    yellow: "#f59e0b",
    blue: "#38bdf8",
    magenta: "#ec4899",
    cyan: "#06b6d4",
    white: "#cbd5e1",
    brightBlack: "#475569",
    brightRed: "#fb923c",
    brightGreen: "#4ade80",
    brightYellow: "#fbbf24",
    brightBlue: "#7dd3fc",
    brightMagenta: "#f472b6",
    brightCyan: "#67d4e2",
    brightWhite: "#ffffff",
  },
});
const agyFitAddon = new FitAddon.FitAddon();
agyTerminal.loadAddon(agyFitAddon);

let agySearchAddon = null;
if (typeof SearchAddon !== "undefined" && SearchAddon.SearchAddon) {
  agySearchAddon = new SearchAddon.SearchAddon();
  agyTerminal.loadAddon(agySearchAddon);
}
if (typeof WebLinksAddon !== "undefined" && WebLinksAddon.WebLinksAddon) {
  agyTerminal.loadAddon(new WebLinksAddon.WebLinksAddon());
}

agyTerminal.open($("agy-terminal"));

agyTerminal.onData((data) => {
  if (!window.abraxius?.antigravity?.write) return;
  window.abraxius.antigravity.write(data).catch(() => {});
});

function fitAntigravityTerminal() {
  const container = $("agy-terminal-container");
  if (container && container.offsetParent !== null && container.clientWidth > 0 && container.clientHeight > 0) {
    try {
      agyFitAddon.fit();
      const dimensions = agyTerminal.proposedDimensions;
      if (dimensions && window.abraxius?.antigravity?.resize) {
        window.abraxius.antigravity.resize(dimensions.cols, dimensions.rows).catch(() => {});
      }
    } catch {}
  }
}

if ($("agy-terminal-container")) {
  new ResizeObserver(() => {
    requestAnimationFrame(fitAntigravityTerminal);
  }).observe($("agy-terminal-container"));
  $("agy-terminal-container").addEventListener("click", () => {
    agyTerminal.focus();
  });
}
window.addEventListener("resize", fitAntigravityTerminal);
document.fonts.ready.then(() => {
  fitAntigravityTerminal();
  try { agyTerminal.refresh(0, agyTerminal.rows - 1); } catch {}
});

const ollamaTerminal = new Terminal({
  convertEol: true,
  cursorBlink: true,
  cursorStyle: "bar",
  disableStdin: false,
  fontFamily: '"Google Sans Code", monospace',
  fontSize: 14,
  lineHeight: 1.4,
  scrollback: 5000,
  theme: {
    background: "#101418",
    foreground: "#eef2f7",
    cursor: "#f59e0b",
    cursorAccent: "#101418",
    selectionBackground: "rgba(245, 158, 11, 0.25)",
    black: "#171c22",
    red: "#f97316",
    green: "#22c55e",
    yellow: "#f59e0b",
    blue: "#38bdf8",
    magenta: "#ec4899",
    cyan: "#06b6d4",
    white: "#cbd5e1",
    brightBlack: "#475569",
    brightRed: "#fb923c",
    brightGreen: "#4ade80",
    brightYellow: "#fbbf24",
    brightBlue: "#7dd3fc",
    brightMagenta: "#f472b6",
    brightCyan: "#67d4e2",
    brightWhite: "#ffffff",
  },
});
const ollamaFitAddon = new FitAddon.FitAddon();
ollamaTerminal.loadAddon(ollamaFitAddon);

let ollamaSearchAddon = null;
if (typeof SearchAddon !== "undefined" && SearchAddon.SearchAddon) {
  ollamaSearchAddon = new SearchAddon.SearchAddon();
  ollamaTerminal.loadAddon(ollamaSearchAddon);
}
if (typeof WebLinksAddon !== "undefined" && WebLinksAddon.WebLinksAddon) {
  ollamaTerminal.loadAddon(new WebLinksAddon.WebLinksAddon());
}

if ($("ollama-terminal")) {
  ollamaTerminal.open($("ollama-terminal"));
}

ollamaTerminal.onData((data) => {
  if (!window.abraxius?.ollama?.ptyWrite) return;
  window.abraxius.ollama.ptyWrite(data).catch(() => {});
});

function fitOllamaTerminal() {
  const container = $("ollama-terminal-container");
  if (container && container.offsetParent !== null && container.clientWidth > 0 && container.clientHeight > 0) {
    try {
      ollamaFitAddon.fit();
    } catch {}
  }
}

if ($("ollama-terminal-container")) {
  new ResizeObserver(() => {
    requestAnimationFrame(fitOllamaTerminal);
  }).observe($("ollama-terminal-container"));
  $("ollama-terminal-container").addEventListener("click", () => {
    ollamaTerminal.focus();
  });
}
window.addEventListener("resize", fitOllamaTerminal);
document.fonts.ready.then(fitOllamaTerminal);

function notice(message = "") { $("notice").textContent = message; $("notice").style.display = message ? "block" : "none"; }
function status(dot, state, detail, online, waiting = false) {
  $(dot).className = `status-dot ${online ? "online" : waiting ? "waiting" : "offline"}`;
  $(state).textContent = online ? "Ready" : waiting ? "Waiting" : "Offline";
  $(`${state.replace(/-state$/, "")}-detail`).textContent = detail;
}
function showPage(id) {
  document.querySelectorAll(".page,.nav").forEach((node) => node.classList.remove("active"));
  $(id).classList.add("active");
  document.querySelector(`.nav[data-page="${id}"]`).classList.add("active");
  [$("page-title").textContent, $("page-subtitle").textContent] = pageMeta[id];
  if (id === "activity") loadEvents();
  if (id === "antigravity") {
    refreshAntigravity();
    setTimeout(fitAntigravityTerminal, 50);
    requestAnimationFrame(fitAntigravityTerminal);
    setTimeout(() => $("agy-prompt")?.focus(), 50);
  }
  if (id === "ollama") {
    refreshOllamaWorkspace();
    setTimeout(() => $("ollama-prompt")?.focus(), 50);
  }
  if (id === "openrouter") {
    refreshOpenRouterWorkspace();
    setTimeout(() => $("openrouter-prompt")?.focus(), 50);
  }
  if (id === "nvidia-nim") {
    refreshNvidiaNimWorkspace();
    setTimeout(() => $("nim-prompt")?.focus(), 50);
  }
}

document.querySelectorAll(".nav").forEach((button) => button.addEventListener("click", () => showPage(button.dataset.page)));
document.querySelectorAll("[data-go]").forEach((button) => button.addEventListener("click", () => showPage(button.dataset.go)));

$("rail-collapse-btn")?.addEventListener("click", () => {
  document.body.classList.toggle("rail-collapsed");
});

$("home-events-refresh")?.addEventListener("click", () => loadEvents());

$("top-global-search")?.addEventListener("keydown", (e) => {
  if (e.key === "Enter" && e.target.value.trim()) {
    const term = e.target.value.trim().toLowerCase();
    const matchNav = Array.from(document.querySelectorAll(".nav")).find((n) => n.textContent.toLowerCase().includes(term));
    if (matchNav) {
      showPage(matchNav.dataset.page);
    }
  }
});

window.addEventListener("keydown", (e) => {
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") {
    e.preventDefault();
    $("top-global-search")?.focus();
  }
});

async function refresh() {
  try {
    latestHealth = await window.abraxius.health();
    notice();
    status("server-dot", "server-state", `PID ${latestHealth.pid || "local"} · ${Math.round(latestHealth.uptime || 0)}s uptime`, true);
    status("studio-dot", "studio-state", latestHealth.connected ? `${latestHealth.toolsLoaded} tools loaded` : "Legacy MCP transport", latestHealth.connected, !latestHealth.connected);
    status("plugin-dot", "plugin-state", latestHealth.pluginConnected ? `${latestHealth.pluginEvents} events received` : "Open the Abraxius Studio plugin", latestHealth.pluginConnected, !latestHealth.pluginConnected);
    const hostStatusText = latestHealth.pluginConnected ? "Studio connected" : "Host ready";
    $("rail-dot").className = "online"; $("rail-text").textContent = hostStatusText;
    if ($("top-host-dot")) $("top-host-dot").className = latestHealth.pluginConnected ? "status-dot online" : "status-dot waiting";
    if ($("top-host-text")) $("top-host-text").textContent = hostStatusText;
    $("checklist").innerHTML = [
      [true,"Local host is running","Ports 13469–13471 are supervised by Abraxius."],
      [latestHealth.pluginConnected,"Studio companion is connected","Enable HTTP requests and open the companion plugin in Studio."],
      [latestHealth.connected,"MCP edit transport is connected","Required for guarded source pushes and multi_edit."],
    ].map(([ok,title,text]) => `<div class="check ${ok ? "ok":"wait"}"><strong>${title}</strong>${text}</div>`).join("");
  } catch (error) {
    latestHealth = undefined; notice(error.message); status("server-dot","server-state","The local host is not responding",false); $("rail-dot").className="offline"; $("rail-text").textContent="Host offline";
    if ($("top-host-dot")) $("top-host-dot").className = "status-dot offline";
    if ($("top-host-text")) $("top-host-text").textContent = "Host offline";
  }
}

async function loadEvents() {
  try {
    const { events = [] } = await window.abraxius.events(60);
    $("events").className = events.length ? "event-list" : "event-list empty";
    $("events").innerHTML = events.length ? events.slice().reverse().map((event) => {
      const when = event.timestamp || event.createdAt || event.time || "";
      const label = event.type || event.kind || "event";
      const detail = event.message || event.path || JSON.stringify(event.data || event);
      return `<div class="event"><time>${String(when).replace("T"," ").slice(0,19)}</time><div><strong>${escapeHtml(label)}</strong><br>${escapeHtml(String(detail))}</div></div>`;
    }).join("") : "No companion events yet.";
  } catch (error) { $("events").className="event-list empty"; $("events").textContent=error.message; }
}
function escapeHtml(value) { const node=document.createElement("span"); node.textContent=value; return node.innerHTML; }
async function run(button, args) {
  button.disabled = true;
  const cmdStr = `abraxius ${args.join(" ")}`;
  $("command-output").textContent = `Running: ${cmdStr}\n`;
  try {
    const result = await window.abraxius.runCli(args);
    if (result && result.ok) {
      $("command-output").textContent = result.output || "Completed successfully.";
    } else if (result) {
      const exitInfo = result.code !== null && result.code !== undefined
        ? `exit code ${result.code}`
        : result.signal
        ? `signal ${result.signal}`
        : "failed";
      let text = `Command: ${result.command || cmdStr}\n`;
      text += `Status: Failed (${exitInfo})\n`;
      text += `Error: ${result.error || "Command failed"}\n`;

      const extraStderr = result.stderr && result.stderr !== result.error;
      const extraStdout = result.stdout && result.stdout !== result.error;
      if (extraStderr || extraStdout) {
        text += `\n--- Output Details ---\n`;
        if (extraStderr) text += `[stderr]\n${result.stderr}\n`;
        if (extraStdout) text += `[stdout]\n${result.stdout}\n`;
      }
      $("command-output").textContent = text.trim();
    } else {
      $("command-output").textContent = "Error: No response from CLI execution.";
    }
    await refresh();
  } catch (error) {
    $("command-output").textContent = `Error: ${error.message}`;
  } finally {
    button.disabled = false;
  }
}

let agyPromptTimer = null;
let agyPromptStartTime = 0;

function updateAgyExecutionTimer() {
  if (!agyPromptStartTime) return;
  const elapsedSec = ((Date.now() - agyPromptStartTime) / 1000).toFixed(1);
  if ($("agy-duration")) {
    $("agy-duration").textContent = `${elapsedSec}s`;
    $("agy-duration").className = "agy-badge busy";
  }
}

function appendAntigravityOutput(rawText) {
  if (!rawText) return;
  agyTerminal.write(scrubSecrets(rawText));
}

function renderAntigravityStatus(value) {
  const session = value?.session || value || {};
  const connected = session.ready === true;
  const connecting = session.state === "connecting" || session.state === "reconnecting";

  if ($("agy-dot")) {
    $("agy-dot").className = `status-dot ${connected ? "online" : connecting ? "waiting" : "offline"}`;
  }
  if ($("agy-state")) {
    $("agy-state").textContent = session.busy ? "Working" : session.queued > 0 ? "Queued" : connected ? "Ready" : connecting ? "Connecting" : "Stopped";
  }
  if ($("agy-detail")) {
    $("agy-detail").textContent = session.busy
      ? `PTY ${session.pid || "--"} · Prompt executing`
      : session.pid
      ? `PTY ${session.pid} · Direct input ready`
      : session.state === "reconnecting"
      ? `Reconnecting (attempt ${session.reconnectAttempt || 1}, next in ${Math.round((session.reconnectDelay || 0) / 1000)}s)`
      : `Session ${session.state || "stopped"}`;
  }
  if (agyTerminal && agyTerminal.options) {
    agyTerminal.options.cursorBlink = connected && !session.busy;
  }

  const writeEnabled = session.dangerouslySkipPermissions === true;
  if ($("agy-write-toggle")) $("agy-write-toggle").checked = writeEnabled;
  if ($("agy-permission-dot")) $("agy-permission-dot").className = `status-dot ${writeEnabled ? "waiting" : "online"}`;
  if ($("agy-permission-state")) $("agy-permission-state").textContent = writeEnabled ? "Write Bypass" : "Approval Required";
  if ($("agy-header-perm-badge")) {
    $("agy-header-perm-badge").className = `agy-perm-badge ${writeEnabled ? "bypass-active" : "approval-required"}`;
  }
  if ($("agy-permission-detail")) {
    $("agy-permission-detail").textContent = writeEnabled
      ? "Tool permission prompts are bypassed. Changing this restarts the CLI."
      : "Antigravity must request approval before tool use. Changing this restarts the CLI.";
  }

  if ($("agy-queue")) {
    $("agy-queue").textContent = `${session.queued || 0} queued`;
    $("agy-queue").className = `agy-badge ${session.busy ? "busy" : session.queued > 0 ? "queued" : ""}`;
  }
  if ($("agy-pid-pill")) {
    $("agy-pid-pill").textContent = session.pid ? `PID ${session.pid}` : "PTY --";
  }

  const sendDisabled = !connected || session.busy;
  if ($("agy-send")) $("agy-send").disabled = sendDisabled;
  if ($("agy-interrupt")) $("agy-interrupt").disabled = !session.busy;
  if ($("agy-restart")) $("agy-restart").disabled = connecting;
  if ($("agy-stop")) $("agy-stop").disabled = session.state === "stopped";
}

async function refreshAntigravity() {
  try {
    let status = await window.abraxius.antigravity.status();
    if (!agyAutoStartAttempted && status?.session?.state === "stopped") {
      agyAutoStartAttempted = true;
      await window.abraxius.antigravity.start();
      status = await window.abraxius.antigravity.status();
    }
    renderAntigravityStatus(status);
    lastAgyStatusError = "";
  } catch (error) {
    if (error.message !== lastAgyStatusError) {
      notice(`Antigravity status error: ${error.message}`);
      lastAgyStatusError = error.message;
    }
  }
}

function adjustPromptHeight() {
  const promptInput = $("agy-prompt");
  if (!promptInput) return;
  promptInput.style.height = "auto";
  const newHeight = Math.min(Math.max(promptInput.scrollHeight, 36), 120);
  promptInput.style.height = `${newHeight}px`;
}

async function sendAntigravityPrompt() {
  const promptInput = $("agy-prompt");
  if (!promptInput) return;
  const prompt = promptInput.value.trim();
  if (!prompt) return;

  if (window.ptyWorkspaceManager && window.ptyWorkspaceManager.composerMode === "shell") {
    const sessionId = window.ptyWorkspaceManager.paneSessions[window.ptyWorkspaceManager.focusedPaneIndex] || "agy-default";
    window.ptyWorkspaceManager.writeToSession(sessionId, prompt + "\r");
    promptInput.value = "";
    adjustPromptHeight();
    return;
  }

  if ($("agy-response")) $("agy-response").textContent = "Antigravity is working…";
  
  agyPromptStartTime = Date.now();
  if (agyPromptTimer) clearInterval(agyPromptTimer);
  agyPromptTimer = setInterval(updateAgyExecutionTimer, 200);

  if ($("agy-send")) $("agy-send").disabled = true;
  try {
    const result = await window.abraxius.antigravity.prompt(prompt, { timeoutMs: 600000 });
    if ($("agy-response")) $("agy-response").textContent = scrubSecrets(result.text || "Completed without response text.");
    if ($("agy-duration")) {
      const durSec = ((result.durationMs || 0) / 1000).toFixed(1);
      $("agy-duration").textContent = `${durSec}s`;
      $("agy-duration").className = "agy-badge";
    }
  } catch (error) {
    if ($("agy-response")) $("agy-response").textContent = `Error: ${scrubSecrets(error.message)}`;
    if ($("agy-duration")) {
      $("agy-duration").textContent = "Failed";
      $("agy-duration").className = "agy-badge";
    }
  } finally {
    if (agyPromptTimer) {
      clearInterval(agyPromptTimer);
      agyPromptTimer = null;
    }
    agyPromptStartTime = 0;
    await refreshAntigravity();
  }
}

window.abraxius.antigravity.onEvent(({ type, payload }) => {
  if (type === "output") {
    appendAntigravityOutput(payload?.raw || payload?.text || "");
  }
  if (type === "response" && payload) {
    if ($("agy-response")) $("agy-response").textContent = scrubSecrets(payload.text || "Completed without response text.");
    if ($("agy-duration")) {
      const durSec = ((payload.durationMs || 0) / 1000).toFixed(1);
      $("agy-duration").textContent = `${durSec}s`;
      $("agy-duration").className = "agy-badge";
    }
  }
  if (["state", "connected", "exit", "reconnecting", "response", "request-error"].includes(type)) {
    refreshAntigravity();
  }
});

if ($("agy-write-toggle")) {
  $("agy-write-toggle").addEventListener("change", async (event) => {
    const enabled = event.target.checked;
    event.target.disabled = true;
    try {
      await window.abraxius.antigravity.setWriteAccess(enabled);
    } catch (error) {
      notice(`Permission error: ${error.message}`);
    } finally {
      event.target.disabled = false;
      await refreshAntigravity();
    }
  });
}

function setAgyViewMode(mode) {
  const main = $("agy-workspace-main");
  if (!main) return;
  const btnSplit = $("agy-view-split");
  const btnTerm = $("agy-view-term");
  const btnResponse = $("agy-view-response");

  if (btnSplit) { btnSplit.classList.toggle("active", mode === "split"); btnSplit.setAttribute("aria-selected", mode === "split" ? "true" : "false"); }
  if (btnTerm) { btnTerm.classList.toggle("active", mode === "term"); btnTerm.setAttribute("aria-selected", mode === "term" ? "true" : "false"); }
  if (btnResponse) { btnResponse.classList.toggle("active", mode === "response"); btnResponse.setAttribute("aria-selected", mode === "response" ? "true" : "false"); }

  main.classList.remove("view-split", "view-term", "view-response");
  main.classList.add(`view-${mode}`);

  try { localStorage.setItem("abraxius_agy_view_mode", mode); } catch {}

  requestAnimationFrame(() => {
    setTimeout(fitAntigravityTerminal, 30);
  });
}

const savedAgyView = (() => {
  try { return localStorage.getItem("abraxius_agy_view_mode"); } catch { return null; }
})();
setAgyViewMode(savedAgyView && ["split", "term", "response"].includes(savedAgyView) ? savedAgyView : "term");

if ($("agy-view-split")) $("agy-view-split").addEventListener("click", () => setAgyViewMode("split"));
if ($("agy-view-term")) $("agy-view-term").addEventListener("click", () => setAgyViewMode("term"));
if ($("agy-view-response")) $("agy-view-response").addEventListener("click", () => setAgyViewMode("response"));
if ($("agy-close-response")) $("agy-close-response").addEventListener("click", () => setAgyViewMode("term"));

if ($("agy-send")) $("agy-send").addEventListener("click", sendAntigravityPrompt);
if ($("agy-prompt")) {
  $("agy-prompt").addEventListener("input", adjustPromptHeight);
  $("agy-prompt").addEventListener("keydown", (event) => {
    if (event.key === "Enter" && event.ctrlKey) {
      event.preventDefault();
      sendAntigravityPrompt();
    } else if (event.key === "Escape") {
      $("agy-prompt").blur();
    }
  });
}

const overflowDetails = $("agy-overflow-details");
if (overflowDetails) {
  overflowDetails.querySelectorAll("button").forEach((btn) => {
    btn.addEventListener("click", () => overflowDetails.removeAttribute("open"));
  });
}

if ($("agy-header-perm-badge")) {
  $("agy-header-perm-badge").addEventListener("click", (e) => {
    e.stopPropagation();
    if (overflowDetails) {
      if (overflowDetails.hasAttribute("open")) {
        overflowDetails.removeAttribute("open");
      } else {
        overflowDetails.setAttribute("open", "");
      }
    }
  });
}

document.addEventListener("click", (event) => {
  if (overflowDetails && overflowDetails.hasAttribute("open")) {
    if (!overflowDetails.contains(event.target)) {
      overflowDetails.removeAttribute("open");
    }
  }
});

if ($("agy-interrupt")) {
  $("agy-interrupt").addEventListener("click", async () => {
    await window.abraxius.antigravity.interrupt();
    await refreshAntigravity();
  });
}
if ($("agy-restart")) {
  $("agy-restart").addEventListener("click", async () => {
    await window.abraxius.antigravity.restart();
    await refreshAntigravity();
  });
}
if ($("agy-stop")) {
  $("agy-stop").addEventListener("click", async () => {
    await window.abraxius.antigravity.stop();
    await refreshAntigravity();
  });
}

const clearTerminal = () => agyTerminal.clear();
if ($("agy-clear")) $("agy-clear").addEventListener("click", clearTerminal);

if ($("agy-copy-response")) {
  $("agy-copy-response").addEventListener("click", async () => {
    const text = $("agy-response") ? $("agy-response").textContent : "";
    if (text) {
      try {
        await navigator.clipboard.writeText(text);
        const originalText = $("agy-copy-response").textContent;
        $("agy-copy-response").textContent = "Copied!";
        setTimeout(() => { $("agy-copy-response").textContent = originalText; }, 1500);
      } catch {}
    }
  });
}

window.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    const active = document.activeElement;
    if (active && active.id === "agy-prompt") {
      active.blur();
    } else {
      const main = $("agy-workspace-main");
      if (main && (main.classList.contains("view-split") || main.classList.contains("view-response"))) {
        setAgyViewMode("term");
      }
    }
  }
});

$("refresh").addEventListener("click", refresh); $("activity-refresh").addEventListener("click", loadEvents);
$("restart").addEventListener("click", async () => { $("restart").disabled=true; try { await window.abraxius.restartHost(); await refresh(); } catch(e){notice(e.message)} finally{$("restart").disabled=false;} });
$("pull").addEventListener("click", () => { const args=["pull"]; const target=$("pull-target").value.trim(); if(target) args.push("--target",target); args.push($("pull-dir").value.trim()||"game"); run($("pull"),args); });
$("push").addEventListener("click", () => { const file=$("push-file").value.trim(); if(!file){$("command-output").textContent="Choose a mapped Luau file first.";return;} run($("push"),["push",file]); });
$("pending-refresh").addEventListener("click", async () => { try { $("command-output").textContent=JSON.stringify(await window.abraxius.pending(),null,2); } catch(e){$("command-output").textContent=e.message;} });
$("open-log").addEventListener("click",()=>window.abraxius.openLog()); $("open-data").addEventListener("click",()=>window.abraxius.openData());
$("health-json").addEventListener("click",async()=>{await refresh(); const text=JSON.stringify(latestHealth||{},null,2); await navigator.clipboard.writeText(text); $("diagnostic-output").textContent=text;});
$("autostart").addEventListener("change",async(event)=>{event.target.checked=await window.abraxius.setAutostart(event.target.checked);});
window.abraxius.getAutostart().then((enabled)=>{$("autostart").checked=enabled;});
window.abraxius.onHostExit((code)=>notice(`The local host exited with code ${code}.`));
refresh(); refreshAntigravity(); setInterval(refresh,5000); setInterval(refreshAntigravity,2000);

/* ==========================================================================
   Abraxius Ollama Workspace Renderer Module
   ========================================================================== */
let ollamaState = {
  status: null,
  activeSessionId: null,
  isGenerating: false,
  activeResponseElement: null,
};

function renderOllamaPtyStatus(session) {
  session = session || {};
  const connected = session.ready === true;
  const starting = session.state === "starting";

  if ($("ollama-pty-dot")) {
    $("ollama-pty-dot").className = `status-dot ${connected ? "online" : starting ? "waiting" : "offline"}`;
  }
  if ($("ollama-pty-state")) {
    $("ollama-pty-state").textContent = session.state === "blocked"
      ? "Access blocked"
      : session.busy ? "Working" : connected ? "Ready" : starting ? "Starting" : "Stopped";
  }
  if ($("ollama-pty-detail")) {
    $("ollama-pty-detail").textContent = session.pid
      ? `PTY ${session.pid} · ${session.model || "ollama"}`
      : session.reason || `PTY ${session.state || "stopped"}`;
  }
  if ($("ollama-pty-interrupt")) {
    $("ollama-pty-interrupt").disabled = !connected;
  }
}

function setOllamaViewMode(mode) {
  const main = $("ollama-workspace-main");
  if (!main) return;
  main.classList.remove("view-chat", "view-term", "view-split");
  main.classList.add(`view-${mode}`);

  document.querySelectorAll("#ollama-view-toggle .agy-view-btn").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.ollamaView === mode);
  });

  if (mode === "term" || mode === "split") {
    setTimeout(fitOllamaTerminal, 50);
    requestAnimationFrame(fitOllamaTerminal);
  }
}

async function refreshOllamaWorkspace() {
  if (!window.abraxius || !window.abraxius.ollama) return;

  try {
    const statusData = await window.abraxius.ollama.status().catch(() => ({ online: false, models: [], settings: {} }));
    ollamaState.status = statusData;

    const online = statusData.online === true;
    const dot = $("ollama-dot");
    const stateEl = $("ollama-state");
    const detailEl = $("ollama-detail");
    const countPill = $("ollama-model-count-pill");
    const privacyBadge = $("ollama-privacy-badge");
    const modelSelect = $("ollama-model-select");
    const accessGranted = statusData.settings?.ptyAccessGranted === true;
    const accessToggle = $("ollama-access-toggle");
    const accessState = $("ollama-access-state");
    const accessDot = $("ollama-access-dot");
    const accessBadge = $("ollama-access-badge");
    if (accessToggle) accessToggle.checked = accessGranted;
    if (accessState) accessState.textContent = accessGranted ? "Local access enabled" : "Access blocked";
    if (accessDot) accessDot.className = `status-dot ${accessGranted ? "waiting" : "offline"}`;
    if (accessBadge) accessBadge.className = `agy-perm-badge ${accessGranted ? "bypass-active" : "approval-required"}`;
    const accessDetail = $("ollama-access-detail");
    if (accessDetail) accessDetail.textContent = accessGranted
      ? "Authorized only for the configured Ollama executable and endpoint. Electron sandboxing remains enabled."
      : "Access is blocked until you approve it. This does not disable Electron sandboxing or grant arbitrary shell access.";

    if (dot) dot.className = `status-dot ${online ? "online" : "offline"}`;
    if (stateEl) stateEl.textContent = online ? "Online" : "Offline";
    if (detailEl) detailEl.textContent = statusData.endpoint || "http://127.0.0.1:11434";
    if (countPill) countPill.textContent = `${statusData.count || 0} models`;
    if (privacyBadge) privacyBadge.textContent = "Local Execution (Private Allowed)";

    if (modelSelect) {
      const currentSelected = statusData.settings?.selectedModel || modelSelect.value;
      if (statusData.models && statusData.models.length > 0) {
        modelSelect.innerHTML = statusData.models.map((m) => {
          const remoteTag = m.isRemote ? " (Cloud/Remote)" : "";
          const paramTag = m.parameterSize ? ` [${m.parameterSize}]` : "";
          return `<option value="${escapeHtml(m.name)}">${escapeHtml(m.name)}${paramTag}${remoteTag}</option>`;
        }).join("");
        if (currentSelected && statusData.models.some((m) => m.name === currentSelected)) {
          modelSelect.value = currentSelected;
        } else if (statusData.models.length > 0) {
          const preferred = ["qwen3.5:9b-q4_K_M", "qwen3-coder:30b", "qwen3-coder", "devstral-small-2", "devstral", "gpt-oss:20b"].find((name) => statusData.models.some((m) => m.name === name));
          modelSelect.value = preferred || statusData.models[0].name;
        }
      } else {
        modelSelect.innerHTML = `<option value="">No models found (Run ollama pull)</option>`;
      }
    }

    const setEndpoint = $("ollama-set-endpoint");
    const setTemp = $("ollama-set-temp");
    const setCtx = $("ollama-set-ctx");
    const setMem = $("ollama-set-memory");

    if (setEndpoint && statusData.settings?.endpoint) setEndpoint.value = statusData.settings.endpoint;
    if (setTemp && statusData.settings?.temperature !== undefined) setTemp.value = statusData.settings.temperature;
    if (setCtx && statusData.settings?.numCtx !== undefined) setCtx.value = statusData.settings.numCtx;
    if (setMem && statusData.settings?.useMemory !== undefined) setMem.checked = statusData.settings.useMemory;
    if ($("ollama-internet-toggle")) $("ollama-internet-toggle").checked = statusData.settings?.internetAccessGranted === true;

    if (window.abraxius.ollama.ptyStatus) {
      const ptyStat = statusData.ptySession || await window.abraxius.ollama.ptyStatus().catch(() => ({ state: "stopped" }));
      renderOllamaPtyStatus(ptyStat);
    }
  } catch (err) {
    console.error("Failed to refresh Ollama workspace:", err);
  }
}

async function sendOllamaPrompt() {
  const promptInput = $("ollama-prompt");
  if (!promptInput) return;
  const prompt = promptInput.value.trim();
  if (!prompt || ollamaState.isGenerating) return;

  const modelSelect = $("ollama-model-select");
  const model = modelSelect ? modelSelect.value : "";
  if (!model) {
    alert("No model selected. Please select a model or download one using `ollama pull <model>`.");
    return;
  }

  const welcomeMsg = $("ollama-welcome");
  if (welcomeMsg) welcomeMsg.style.display = "none";

  const container = $("ollama-chat-container");
  if (!container) return;

  // Render User Message
  const userMsgDiv = document.createElement("div");
  userMsgDiv.className = "ollama-msg user";
  userMsgDiv.innerHTML = `
    <div class="ollama-msg-meta">
      <span>You</span>
      <time>${new Date().toLocaleTimeString()}</time>
    </div>
    <div class="ollama-msg-body">${escapeHtml(prompt)}</div>
  `;
  container.appendChild(userMsgDiv);

  // Render Assistant Message Placeholder
  const assistantMsgDiv = document.createElement("div");
  assistantMsgDiv.className = "ollama-msg assistant";
  const msgId = `ollama-resp-${Date.now()}`;
  assistantMsgDiv.innerHTML = `
    <div class="ollama-msg-meta">
      <span>${escapeHtml(model)}</span>
      <span class="ollama-privacy-info" id="priv-${msgId}">Memory recalled</span>
    </div>
    <div class="ollama-msg-body" id="${msgId}">Thinking…</div>
    <button class="ollama-copy-btn" onclick="copyOllamaMessage('${msgId}')">Copy</button>
  `;
  container.appendChild(assistantMsgDiv);
  container.scrollTop = container.scrollHeight;

  promptInput.value = "";
  promptInput.style.height = "auto";

  ollamaState.isGenerating = true;
  ollamaState.activeResponseElement = $(msgId);
  const sessionId = String(Date.now());
  ollamaState.activeSessionId = sessionId;

  if ($("ollama-send")) $("ollama-send").disabled = true;
  if ($("ollama-stop")) $("ollama-stop").disabled = false;

  try {
    const agentMode = $("ollama-agent-toggle")?.checked === true;
    const res = await (agentMode ? window.abraxius.ollama.agent : window.abraxius.ollama.chat)({
      prompt,
      model,
      sessionId,
      useMemory: $("ollama-set-memory") ? $("ollama-set-memory").checked : true,
      temperature: $("ollama-set-temp") ? Number($("ollama-set-temp").value) : 0.7,
      numCtx: $("ollama-set-ctx") ? Number($("ollama-set-ctx").value) : 4096,
      endpoint: $("ollama-set-endpoint") ? $("ollama-set-endpoint").value.trim() : "http://127.0.0.1:11434",
      useInternet: $("ollama-internet-toggle")?.checked === true,
      maxIterations: 5,
      allowMutations: $("ollama-agent-mutations")?.checked === true,
    });

    if (res && res.error) {
      if ($(msgId) && $(msgId).textContent === "Thinking…") {
        $(msgId).textContent = `Error: ${res.error}`;
        assistantMsgDiv.classList.add("error");
      }
    }
  } catch (err) {
    if ($(msgId)) $(msgId).textContent = `Error: ${err.message}`;
    assistantMsgDiv.classList.add("error");
  } finally {
    ollamaState.isGenerating = false;
    ollamaState.activeSessionId = null;
    ollamaState.activeResponseElement = null;
    if ($("ollama-send")) $("ollama-send").disabled = false;
    if ($("ollama-stop")) $("ollama-stop").disabled = true;
  }
}

/* ========================================================================
   NVIDIA NIM Workspace Renderer
   ======================================================================== */
let nvidiaNimState = { activeSessionId: null, isGenerating: false, activeResponseElement: null };
const nvidiaNimSessions = new Map();

function renderNvidiaNimStatus(status = {}) {
  const configured = status.hasApiKey === true;
  if ($("nim-dot")) $("nim-dot").className = `status-dot ${configured ? "online" : "waiting"}`;
  if ($("nim-state")) $("nim-state").textContent = configured ? "Ready" : "Needs API key";
  if ($("nim-detail")) $("nim-detail").textContent = status.endpoint || "https://integrate.api.nvidia.com/v1";
  if ($("nim-key-state")) $("nim-key-state").textContent = configured ? "● Key OK" : "● API key not set";
}

async function refreshNvidiaNimWorkspace() {
  if (!window.abraxius?.nvidiaNim) return;
  const settings = await window.abraxius.nvidiaNim.getSettings().catch(() => ({}));
  renderNvidiaNimStatus(settings);
  if ($("nim-endpoint") && settings.endpoint) $("nim-endpoint").value = settings.endpoint;
  if ($("nim-model-select") && settings.model) $("nim-model-select").value = settings.model;
  if ($("nim-temperature") && settings.temperature !== undefined) $("nim-temperature").value = settings.temperature;
  if ($("nim-top-p") && settings.topP !== undefined) $("nim-top-p").value = settings.topP;
  if ($("nim-max-tokens") && settings.maxTokens !== undefined) $("nim-max-tokens").value = settings.maxTokens;
  if ($("nim-reasoning-budget") && settings.reasoningBudget !== undefined) $("nim-reasoning-budget").value = settings.reasoningBudget;
}

function sendNvidiaNimPrompt() {
  const input = $("nim-prompt");
  const prompt = input?.value.trim();
  if (!prompt || nvidiaNimState.isGenerating) return;
  const container = $("nim-chat-container");
  $("nim-welcome")?.remove();
  const user = document.createElement("div"); user.className = "ollama-msg user"; user.textContent = `You: ${prompt}`; container?.appendChild(user);
  const assistant = document.createElement("div"); assistant.className = "ollama-msg assistant";
  const responseId = `nim-response-${Date.now()}`;
  const statusId = `nim-status-${Date.now()}`;
  assistant.innerHTML = `<div class="ollama-msg-meta"><span>${escapeHtml($("nim-model-select")?.value || "Nemotron")}</span><span id="${statusId}">Streaming…</span></div><div class="ollama-msg-body" id="${responseId}">Thinking…</div>`;
  container?.appendChild(assistant);
  if (container) container.scrollTop = container.scrollHeight;
  input.value = "";
  const sessionId = `nim-ui-${Date.now()}`;
  nvidiaNimState = { activeSessionId: sessionId, isGenerating: true, activeResponseElement: $(responseId) };
  nvidiaNimSessions.set(sessionId, { responseEl: $(responseId), statusEl: $(statusId), source: "ui", prompt });

  $("nim-send").disabled = true; $("nim-stop").disabled = false; $("nim-send").textContent = "Streaming…";
  window.abraxius.nvidiaNim.chat({ prompt, model: $("nim-model-select")?.value, sessionId, endpoint: $("nim-endpoint")?.value.trim(), temperature: Number($("nim-temperature")?.value), topP: Number($("nim-top-p")?.value), maxTokens: Number($("nim-max-tokens")?.value), reasoningBudget: Number($("nim-reasoning-budget")?.value) }).then((result) => {
    if (!result?.ok && $(responseId)) $(responseId).textContent = `Error: ${result.error}`;
  }).catch((error) => { if ($(responseId)) $(responseId).textContent = `Error: ${error.message}`; }).finally(() => {
    if (nvidiaNimState.activeSessionId === sessionId) {
      nvidiaNimState = { activeSessionId: null, isGenerating: false, activeResponseElement: null };
      $("nim-send").disabled = false; $("nim-stop").disabled = true; $("nim-send").textContent = "Send";
    }
  });
}

if (window.abraxius?.nvidiaNim) {
  window.abraxius.nvidiaNim.onChatStart(({ sessionId, prompt, source, status, model }) => {
    if (!sessionId) return;
    if (nvidiaNimSessions.has(sessionId)) {
      const sess = nvidiaNimSessions.get(sessionId);
      if (sess.statusEl) sess.statusEl.textContent = status === "queued" ? "Queued…" : "Streaming…";
      return;
    }
    const container = $("nim-chat-container");
    $("nim-welcome")?.remove();
    const user = document.createElement("div");
    user.className = "ollama-msg user";
    user.innerHTML = `<span style="background:rgba(6,182,212,0.2);color:#38bdf8;padding:2px 6px;border-radius:4px;font-size:11px;margin-right:6px;font-weight:600;">[CLI]</span>You: ${escapeHtml(prompt || "")}`;
    container?.appendChild(user);

    const assistant = document.createElement("div");
    assistant.className = "ollama-msg assistant";
    const responseId = `nim-response-${sessionId}`;
    const statusId = `nim-status-${sessionId}`;
    assistant.innerHTML = `<div class="ollama-msg-meta"><span style="background:rgba(249,115,22,0.2);color:#fb923c;padding:2px 6px;border-radius:4px;font-size:11px;font-weight:600;">CLI Request</span><span>${escapeHtml(model || "Nemotron")}</span><span id="${statusId}">${status === "queued" ? "Queued…" : "Streaming…"}</span></div><div class="ollama-msg-body" id="${responseId}">${status === "queued" ? "Queued in NIM pipeline…" : "Thinking…"}</div>`;
    container?.appendChild(assistant);
    if (container) container.scrollTop = container.scrollHeight;

    nvidiaNimSessions.set(sessionId, { responseEl: $(responseId), statusEl: $(statusId), source: source || "cli", prompt });
  });

  window.abraxius.nvidiaNim.onReasoning(({ sessionId, chunk }) => {
    if ($("nim-reasoning")) {
      $("nim-reasoning").textContent = $("nim-reasoning").textContent === "Reasoning will appear here…" ? chunk : $("nim-reasoning").textContent + chunk;
    }
  });

  window.abraxius.nvidiaNim.onChunk(({ sessionId, chunk }) => {
    const session = nvidiaNimSessions.get(sessionId);
    const el = session?.responseEl || (sessionId === nvidiaNimState.activeSessionId ? nvidiaNimState.activeResponseElement : null);
    if (el) {
      if (el.textContent === "Thinking…" || el.textContent === "Queued in NIM pipeline…") {
        el.textContent = chunk;
      } else {
        el.textContent += chunk;
      }
    }
  });

  window.abraxius.nvidiaNim.onChatEnd(({ sessionId, ok, error, cancelled }) => {
    const session = nvidiaNimSessions.get(sessionId);
    if (session) {
      if (session.statusEl) {
        if (ok) session.statusEl.textContent = "Completed";
        else if (cancelled) session.statusEl.textContent = "Cancelled";
        else if (error) session.statusEl.textContent = "Error";
      }
      if (error && session.responseEl) {
        if (session.responseEl.textContent === "Thinking…" || session.responseEl.textContent === "Queued in NIM pipeline…") {
          session.responseEl.textContent = `Error: ${error}`;
        }
      }
    }
    if (nvidiaNimState.activeSessionId === sessionId) {
      nvidiaNimState = { activeSessionId: null, isGenerating: false, activeResponseElement: null };
      $("nim-send").disabled = false; $("nim-stop").disabled = true; $("nim-send").textContent = "Send";
    }
  });
}

/* ========================================================================
   OpenRouter Workspace Renderer
   ======================================================================== */
let openRouterState = {
  activeSessionId: null,
  isGenerating: false,
  activeResponseElement: null,
  messages: [],
};

function appendOpenRouterActivity(line) {
  const consoleEl = $("openrouter-activity");
  if (!consoleEl) return;
  if (consoleEl.textContent === "OpenRouter activity will appear here…") consoleEl.textContent = "";
  consoleEl.textContent += `${new Date().toLocaleTimeString()} ${line}\n`;
  consoleEl.scrollTop = consoleEl.scrollHeight;
}

function appendOpenRouterTranscript(kind, title, content) {
  const container = $("openrouter-chat-container");
  if (!container) return;
  $("openrouter-welcome")?.remove();
  const message = document.createElement("div");
  message.className = `ollama-msg ${kind}`;
  const meta = document.createElement("div");
  meta.className = "ollama-msg-meta";
  meta.innerHTML = `<span>${escapeHtml(title)}</span><time>${new Date().toLocaleTimeString()}</time>`;
  const body = document.createElement("div");
  body.className = "ollama-msg-body";
  body.textContent = typeof content === "string" ? content : JSON.stringify(content, null, 2);
  message.append(meta, body);
  container.appendChild(message);
  container.scrollTop = container.scrollHeight;
}

function renderOpenRouterStatus(status = {}) {
  const configured = status.hasApiKey === true;
  const online = configured && status.online !== false;
  if ($("openrouter-dot")) $("openrouter-dot").className = `status-dot ${online ? "online" : "waiting"}`;
  if ($("openrouter-state")) $("openrouter-state").textContent = configured ? (online ? "Ready" : "Unavailable") : "Needs API key";
  if ($("openrouter-detail")) $("openrouter-detail").textContent = status.endpoint || "https://openrouter.ai/api/v1";
  if ($("openrouter-key-state")) {
    $("openrouter-key-state").textContent = configured ? "● Key OK" : "● Key missing";
    $("openrouter-key-state").classList.toggle("openrouter-key-ok", configured);
    $("openrouter-key-state").classList.toggle("openrouter-key-missing", !configured);
  }
  if ($("openrouter-privacy-badge")) $("openrouter-privacy-badge").textContent = "Remote model · private memory excluded";
}

let lastOpenRouterPrompt = "";

async function refreshOpenRouterWorkspace() {
  if (!window.abraxius?.openrouter) return;
  try {
    const settings = await window.abraxius.openrouter.getSettings().catch(() => ({}));
    const status = await window.abraxius.openrouter.status().catch(() => ({ endpoint: settings.endpoint, hasApiKey: false }));
    renderOpenRouterStatus({ ...status, hasApiKey: status.hasApiKey || settings.hasApiKey });

    if ($("openrouter-endpoint") && settings.endpoint) $("openrouter-endpoint").value = settings.endpoint;
    if ($("openrouter-temperature") && settings.temperature !== undefined) $("openrouter-temperature").value = settings.temperature;
    if ($("openrouter-use-memory") && settings.useMemory !== undefined) $("openrouter-use-memory").checked = settings.useMemory;
    if ($("openrouter-max-retries") && settings.maxRetries !== undefined) $("openrouter-max-retries").value = settings.maxRetries;
    if ($("openrouter-max-backoff") && settings.maxBackoffSeconds !== undefined) $("openrouter-max-backoff").value = settings.maxBackoffSeconds;

    const freeOnly = $("openrouter-filter-select")?.value === "free";
    const modelSelect = $("openrouter-model-select");

    if (status.hasApiKey || settings.hasApiKey) {
      const models = await window.abraxius.openrouter.models({ freeOnly }).catch(() => []);
      if (modelSelect && models.length) {
        modelSelect.innerHTML = models.map((model) => {
          const ctxTag = model.contextLength ? ` (${Math.round(model.contextLength / 1024)}k ctx)` : "";
          const freeBadge = model.isFree ? " [FREE]" : "";
          return `<option value="${escapeHtml(model.id)}">${escapeHtml(model.name || model.id)}${ctxTag}${freeBadge}</option>`;
        }).join("");
        const targetModel = settings.selectedModel || DEFAULT_OPENROUTER_MODEL;
        if (models.some((model) => model.id === targetModel)) {
          modelSelect.value = targetModel;
        } else if (models.length > 0) {
          modelSelect.value = models[0].id;
        }
      } else if (modelSelect) {
        modelSelect.innerHTML = freeOnly
          ? `<option value="inclusionai/ling-3.0-flash:free">Ling-3.0-flash (free)</option>`
          : `<option value="">No models found</option>`;
      }
    }
  } catch (error) {
    renderOpenRouterStatus({ endpoint: "https://openrouter.ai/api/v1", hasApiKey: false });
    console.error("Failed to refresh OpenRouter workspace:", error);
  }
}

function hideOpenRouterRetryBanner() {
  const banner = $("openrouter-retry-banner");
  if (banner) banner.style.display = "none";
}

function showOpenRouterRetryBanner(text) {
  const banner = $("openrouter-retry-banner");
  const textEl = $("openrouter-retry-text");
  if (textEl) textEl.textContent = text;
  if (banner) banner.style.display = "flex";
}

async function sendOpenRouterPrompt(customPrompt) {
  const promptInput = $("openrouter-prompt");
  const prompt = (typeof customPrompt === "string" ? customPrompt : promptInput?.value)?.trim();
  if (!prompt || openRouterState.isGenerating) return;
  lastOpenRouterPrompt = prompt;

  const model = $("openrouter-model-select")?.value;
  if (!model) return notice("Choose an OpenRouter model first.");

  hideOpenRouterRetryBanner();
  appendOpenRouterActivity(`> Request model: ${model}`);

  $("openrouter-welcome")?.style && ($("openrouter-welcome").style.display = "none");
  const container = $("openrouter-chat-container");
  if (!container) return;

  if (typeof customPrompt !== "string") {
    const user = document.createElement("div");
    user.className = "ollama-msg user";
    user.innerHTML = `<div class="ollama-msg-meta"><span>You</span><time>${new Date().toLocaleTimeString()}</time></div><div class="ollama-msg-body">${escapeHtml(prompt)}</div>`;
    container.appendChild(user);
  }

  const assistant = document.createElement("div");
  assistant.className = "ollama-msg assistant";
  const responseId = `openrouter-resp-${Date.now()}`;
  assistant.innerHTML = `<div class="ollama-msg-meta"><span>${escapeHtml(model)}</span><span class="ollama-privacy-info">Private memory excluded</span></div><div class="ollama-msg-body" id="${responseId}">Thinking…</div>`;
  container.appendChild(assistant);
  container.scrollTop = container.scrollHeight;

  if (typeof customPrompt !== "string" && promptInput) {
    promptInput.value = "";
    promptInput.style.height = "auto";
  }

  openRouterState = { ...openRouterState, isGenerating: true, activeResponseElement: $(responseId), activeSessionId: String(Date.now()) };
  $("openrouter-send") && ($("openrouter-send").disabled = true);
  if ($("openrouter-send")) $("openrouter-send").textContent = "Streaming…";
  $("openrouter-stop") && ($("openrouter-stop").disabled = false);

  try {
    const res = await window.abraxius.openrouter.chat({
      prompt,
      model,
      messages: openRouterState.messages,
      sessionId: openRouterState.activeSessionId,
      useMemory: $("openrouter-use-memory")?.checked !== false,
      temperature: Number($("openrouter-temperature")?.value || 0.7),
      endpoint: $("openrouter-endpoint")?.value.trim(),
    });

    hideOpenRouterRetryBanner();

    if (!res?.ok) {
      if (res?.isPartial && res.partialText) {
        if ($(responseId)) $(responseId).textContent = res.partialText;
        const errDiv = document.createElement("div");
        errDiv.className = "openrouter-yolo-warning";
        errDiv.textContent = `[Stream Interrupted: ${res.error}]`;
        assistant.appendChild(errDiv);

        const retryBtn = document.createElement("button");
        retryBtn.className = "ollama-msg-retry-btn";
        retryBtn.textContent = "Retry Turn";
        retryBtn.onclick = () => sendOpenRouterPrompt(prompt);
        assistant.appendChild(retryBtn);
      } else {
        throw new Error(res?.error || "OpenRouter request failed.");
      }
    } else {
      openRouterState.messages = [
        ...openRouterState.messages,
        { role: "user", content: prompt },
        { role: "assistant", content: res.fullText || $(responseId)?.textContent || "" },
      ];
      appendOpenRouterActivity("✓ Response streaming complete");
    }
  } catch (error) {
    hideOpenRouterRetryBanner();
    if ($(responseId)) $(responseId).textContent = `Error: ${error.message}`;
    assistant.classList.add("error");

    const retryBtn = document.createElement("button");
    retryBtn.className = "ollama-msg-retry-btn";
    retryBtn.textContent = "Retry Turn";
    retryBtn.onclick = () => sendOpenRouterPrompt(prompt);
    assistant.appendChild(retryBtn);

    appendOpenRouterActivity(`✗ ${error.message}`);
  } finally {
    openRouterState.isGenerating = false;
    openRouterState.activeSessionId = null;
    openRouterState.activeResponseElement = null;
    if ($("openrouter-send")) $("openrouter-send").disabled = false;
    if ($("openrouter-send")) $("openrouter-send").textContent = "Send";
    if ($("openrouter-stop")) $("openrouter-stop").disabled = true;
  }
}

if (window.abraxius?.openrouter) {
  window.abraxius.openrouter.onChatStart(({ privacyNotice }) => {
    const el = openRouterState.activeResponseElement?.parentElement?.querySelector(".ollama-privacy-info");
    if (el && privacyNotice) el.textContent = privacyNotice;
  });

  window.abraxius.openrouter.onChunk(({ chunk }) => {
    const el = openRouterState.activeResponseElement;
    if (!el) return;
    if (el.textContent === "Thinking…") {
      el.textContent = chunk;
    } else {
      el.textContent += chunk;
    }
    const container = $("openrouter-chat-container");
    if (container) container.scrollTop = container.scrollHeight;
  });

  window.abraxius.openrouter.onRetry(({ attempt, maxRetries, delayMs, status, error, isRateLimit }) => {
    const secs = Math.ceil((delayMs || 1000) / 1000);
    const reasonStr = isRateLimit ? "Throttled by provider (429)" : status ? `HTTP ${status}` : "Network delay";
    const msg = `${reasonStr}. Retrying in ${secs}s (Attempt ${attempt}/${maxRetries})…`;
    showOpenRouterRetryBanner(msg);
    appendOpenRouterActivity(`⏳ Retrying (${attempt}/${maxRetries}) in ${secs}s: ${error || reasonStr}`);
  });

  window.abraxius.openrouter.onTool(({ name, arguments: args }) => {
    appendOpenRouterActivity(`⚙ Tool call: ${name}`);
    appendOpenRouterTranscript("tool", `Tool requested · ${name}`, JSON.stringify(args || {}, null, 2));
  });

  window.abraxius.openrouter.onToolResult(({ name, result }) => {
    appendOpenRouterActivity(`↳ Tool ${name} completed`);
    appendOpenRouterTranscript("tool-result", `Tool result · ${name}`, result);
  });

  window.abraxius.openrouter.onToolApproval(async ({ approvalId, name, arguments: args }) => {
    const approved = window.confirm(`Allow OpenRouter to run ${name}?\n\nArguments:\n${JSON.stringify(args || {}, null, 2)}`);
    appendOpenRouterTranscript("tool-approval", approved ? `Approved · ${name}` : `Denied · ${name}`, JSON.stringify(args || {}, null, 2));
    await window.abraxius.openrouter.approveTool(approvalId, approved);
  });
}

if (window.abraxius && window.abraxius.ollama) {
  window.abraxius.ollama.onChatStart(({ sessionId, privacyNotice }) => {
    if (ollamaState.activeResponseElement && privacyNotice) {
      const parent = ollamaState.activeResponseElement.parentElement;
      const privInfo = parent ? parent.querySelector(".ollama-privacy-info") : null;
      if (privInfo) privInfo.textContent = privacyNotice;
    }
  });

  window.abraxius.ollama.onChunk(({ sessionId, chunk }) => {
    if (ollamaState.activeResponseElement) {
      const el = ollamaState.activeResponseElement;
      if (el.textContent === "Thinking…") {
        el.textContent = chunk;
      } else {
        el.textContent += chunk;
      }
      const container = $("ollama-chat-container");
      if (container) container.scrollTop = container.scrollHeight;
    }
  });

  window.abraxius.ollama.onResearch(({ query, results }) => {
    const container = $("ollama-chat-container");
    if (!container) return;
    const card = document.createElement("div");
    card.className = "ollama-msg research";
    card.innerHTML = `<div class="ollama-msg-meta"><span>Web research · ${escapeHtml(query)}</span><span>${results?.length || 0} sources</span></div>`;
    const body = document.createElement("div");
    body.className = "ollama-msg-body";
    body.textContent = (results || []).map((item, index) => `${index + 1}. ${item.title}\n   ${item.url}`).join("\n");
    card.appendChild(body); container.appendChild(card); container.scrollTop = container.scrollHeight;
  });

  if (window.abraxius.ollama.onPtyEvent) {
    window.abraxius.ollama.onPtyEvent(({ type, payload }) => {
      if (type === "output" && payload && payload.data) {
        ollamaTerminal.write(scrubSecrets(payload.data));
      }
      if (type === "state" || type === "connected" || type === "exit" || type === "fault") {
        renderOllamaPtyStatus(payload);
      }
    });
  }
}

window.copyOllamaMessage = function(id) {
  const el = document.getElementById(id);
  if (el && el.textContent) {
    navigator.clipboard.writeText(el.textContent);
    const btn = el.parentElement ? el.parentElement.querySelector(".ollama-copy-btn") : null;
    if (btn) {
      const orig = btn.textContent;
      btn.textContent = "Copied!";
      setTimeout(() => { btn.textContent = orig; }, 1500);
    }
  }
};

function setupTerminalSearch(prefix, searchAddon, terminal) {
  const toggleBtn = $(`${prefix}-toggle-search`);
  const searchBar = $(`${prefix}-search-bar`);
  const input = $(`${prefix}-search-input`);
  const countEl = $(`${prefix}-search-count`);
  const prevBtn = $(`${prefix}-search-prev`);
  const nextBtn = $(`${prefix}-search-next`);
  const closeBtn = $(`${prefix}-search-close`);

  if (!toggleBtn || !searchBar || !input) return;

  const openSearch = () => {
    searchBar.style.display = "flex";
    input.focus();
    input.select();
  };

  const closeSearch = () => {
    searchBar.style.display = "none";
    if (searchAddon && typeof searchAddon.clearDecoration === "function") {
      searchAddon.clearDecoration();
    }
    terminal.focus();
  };

  toggleBtn.addEventListener("click", () => {
    if (searchBar.style.display === "none" || !searchBar.style.display) {
      openSearch();
    } else {
      closeSearch();
    }
  });

  const performSearch = (direction = "next") => {
    const query = input.value;
    if (!query) {
      if (countEl) countEl.textContent = "0 matches";
      return;
    }
    if (searchAddon) {
      const found = direction === "next"
        ? searchAddon.findNext(query, { caseSensitive: false, regex: false })
        : searchAddon.findPrevious(query, { caseSensitive: false, regex: false });
      if (countEl) countEl.textContent = found ? "Match found" : "No matches";
    }
  };

  input.addEventListener("input", () => performSearch("next"));
  input.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      performSearch(e.shiftKey ? "previous" : "next");
    } else if (e.key === "Escape") {
      e.preventDefault();
      closeSearch();
    }
  });

  if (prevBtn) prevBtn.addEventListener("click", () => performSearch("previous"));
  if (nextBtn) nextBtn.addEventListener("click", () => performSearch("next"));
  if (closeBtn) closeBtn.addEventListener("click", closeSearch);
}

let activePullId = null;

function setupOllamaModelPull() {
  const openBtn = $("ollama-open-pull-btn");
  const pullBar = $("ollama-pull-bar");
  const closeBtn = $("ollama-pull-close-btn");
  const startBtn = $("ollama-pull-start-btn");
  const cancelBtn = $("ollama-pull-cancel-btn");
  const input = $("ollama-pull-input");
  const progressWrap = $("ollama-pull-progress-wrap");
  const statusText = $("ollama-pull-status-text");
  const percentText = $("ollama-pull-percent-text");
  const progressBar = $("ollama-pull-progress-bar");

  if (!openBtn || !pullBar) return;

  openBtn.addEventListener("click", () => {
    pullBar.style.display = pullBar.style.display === "none" ? "block" : "none";
    if (pullBar.style.display === "block" && input) input.focus();
  });

  if (closeBtn) closeBtn.addEventListener("click", () => { pullBar.style.display = "none"; });

  if (startBtn && input) {
    startBtn.addEventListener("click", async () => {
      const model = input.value.trim();
      if (!model) return;

      startBtn.disabled = true;
      input.disabled = true;
      if (progressWrap) progressWrap.style.display = "flex";
      if (statusText) statusText.textContent = `Initiating pull for ${model}…`;
      if (percentText) percentText.textContent = "0%";
      if (progressBar) progressBar.style.width = "0%";

      try {
        const res = await window.abraxius.ollama.pull({ model });
        if (res && res.ok) {
          if (statusText) statusText.textContent = `Successfully pulled ${model}!`;
          if (percentText) percentText.textContent = "100%";
          if (progressBar) progressBar.style.width = "100%";
          setTimeout(() => {
            if (progressWrap) progressWrap.style.display = "none";
            pullBar.style.display = "none";
            refreshOllamaWorkspace();
          }, 1500);
        } else {
          if (statusText) statusText.textContent = `Pull error: ${res?.error || "Unknown error"}`;
        }
      } catch (err) {
        if (statusText) statusText.textContent = `Pull failed: ${err.message}`;
      } finally {
        startBtn.disabled = false;
        input.disabled = false;
        activePullId = null;
      }
    });
  }

  if (cancelBtn) {
    cancelBtn.addEventListener("click", async () => {
      if (window.abraxius?.ollama?.cancelPull) {
        await window.abraxius.ollama.cancelPull(activePullId);
        if (statusText) statusText.textContent = "Pull cancelled by user.";
      }
    });
  }

  if (window.abraxius?.ollama?.onPullProgress) {
    window.abraxius.ollama.onPullProgress(({ pullId, model, progress }) => {
      activePullId = pullId;
      if (statusText) statusText.textContent = progress.status || "Downloading…";
      if (progress.percent !== null && progress.percent !== undefined) {
        if (percentText) percentText.textContent = `${progress.percent}%`;
        if (progressBar) progressBar.style.width = `${progress.percent}%`;
      }
    });
  }
}

document.addEventListener("DOMContentLoaded", () => {
  setupTerminalSearch("agy", agySearchAddon, agyTerminal);
  setupTerminalSearch("ollama", ollamaSearchAddon, ollamaTerminal);
  setupOllamaModelPull();

  document.addEventListener("click", (e) => {
    const card = e.target.closest(".ollama-quick-card");
    if (card && card.dataset.prompt) {
      const promptInput = $("ollama-prompt");
      if (promptInput) {
        promptInput.value = card.dataset.prompt;
        sendOllamaPrompt();
      }
    }
  });

  document.querySelectorAll("#ollama-view-toggle .agy-view-btn").forEach((btn) => {
    btn.addEventListener("click", () => setOllamaViewMode(btn.dataset.ollamaView));
  });

  if ($("ollama-pty-restart")) {
    $("ollama-pty-restart").addEventListener("click", async () => {
      const modelSelect = $("ollama-model-select");
      const model = modelSelect ? modelSelect.value : "";
      try {
        await window.abraxius.ollama.ptyRestart({ model });
        refreshOllamaWorkspace();
      } catch (error) {
        notice(`Ollama PTY unavailable: ${error.message}`);
      }
    });
  }

  if ($("ollama-pty-interrupt")) {
    $("ollama-pty-interrupt").addEventListener("click", async () => {
      await window.abraxius.ollama.ptyInterrupt();
    });
  }

  if ($("ollama-pty-stop")) {
    $("ollama-pty-stop").addEventListener("click", async () => {
      await window.abraxius.ollama.ptyStop();
      refreshOllamaWorkspace();
    });
  }

  if ($("ollama-send")) $("ollama-send").addEventListener("click", sendOllamaPrompt);

  if ($("ollama-prompt")) {
    $("ollama-prompt").addEventListener("input", () => {
      const p = $("ollama-prompt");
      p.style.height = "auto";
      p.style.height = `${Math.min(Math.max(p.scrollHeight, 36), 120)}px`;
    });
    $("ollama-prompt").addEventListener("keydown", (event) => {
      if (event.key === "Enter" && event.ctrlKey) {
        event.preventDefault();
        sendOllamaPrompt();
      }
    });
  }

  if ($("ollama-stop")) {
    $("ollama-stop").addEventListener("click", async () => {
      if (window.abraxius?.ollama) {
        await window.abraxius.ollama.cancel(ollamaState.activeSessionId);
      }
    });
  }

  if ($("ollama-clear")) {
    $("ollama-clear").addEventListener("click", () => {
      const container = $("ollama-chat-container");
      if (container) {
        container.innerHTML = `
          <div class="ollama-welcome-msg" id="ollama-welcome">
            <div class="ollama-welcome-header">
              <div class="ollama-welcome-title">Local Ollama LLM Workspace</div>
              <p>Chat directly with your local LLM models inside Abraxius with active Memory Core retrieval.</p>
            </div>
            <div class="ollama-quick-prompts">
              <button class="ollama-quick-card" data-prompt="Write a Luau Knit service script for handling player data and leaderstats in Roblox Studio.">
                <strong>Create Knit Service</strong>
                <span>Write a Luau leaderstats & data service</span>
              </button>
              <button class="ollama-quick-card" data-prompt="Explain how Abraxius Memory Core isolates project context and prevents prompt injection.">
                <strong>Memory Core Architecture</strong>
                <span>Learn about privacy & context isolation</span>
              </button>
              <button class="ollama-quick-card" data-prompt="Diagnose potential type checking warnings or script sync issues in Roblox Studio.">
                <strong>Debug Luau Code</strong>
                <span>Analyze script errors & type annotations</span>
              </button>
            </div>
          </div>
        `;
      }
    });
  }

  if ($("ollama-refresh-models")) {
    $("ollama-refresh-models").addEventListener("click", () => refreshOllamaWorkspace());
  }

  if ($("ollama-model-select")) {
    $("ollama-model-select").addEventListener("change", async (event) => {
      const selectedModel = event.target.value;
      if (window.abraxius?.ollama) {
        await window.abraxius.ollama.saveSettings({ selectedModel });
      }
    });
  }

  if ($("ollama-save-settings-btn")) {
    $("ollama-save-settings-btn").addEventListener("click", async () => {
      if (window.abraxius?.ollama) {
        const settings = {
          endpoint: $("ollama-set-endpoint") ? $("ollama-set-endpoint").value.trim() : "http://127.0.0.1:11434",
          temperature: $("ollama-set-temp") ? Number($("ollama-set-temp").value) : 0.7,
          numCtx: $("ollama-set-ctx") ? Number($("ollama-set-ctx").value) : 4096,
          useMemory: $("ollama-set-memory") ? $("ollama-set-memory").checked : true,
          internetAccessGranted: $("ollama-internet-toggle")?.checked === true,
        };
        await window.abraxius.ollama.saveSettings(settings);
        alert("Ollama settings saved successfully!");
        refreshOllamaWorkspace();
      }
    });
  }

  if ($("ollama-access-toggle")) {
    $("ollama-access-toggle").addEventListener("change", async (event) => {
      const enabled = event.target.checked;
      if (enabled && !window.confirm("Allow Ollama to use its configured local API and Ollama PTY? This does not grant arbitrary shell access.")) {
        event.target.checked = false;
        return;
      }
      try {
        await window.abraxius.ollama.saveSettings({ ptyAccessGranted: enabled });
        if (!enabled) await window.abraxius.ollama.ptyStop();
        await refreshOllamaWorkspace();
      } catch (error) {
        event.target.checked = !enabled;
        notice(`Ollama access permission failed: ${error.message}`);
      }
    });
  }

  if ($("ollama-access-badge") && $("ollama-settings-details")) {
    $("ollama-access-badge").addEventListener("click", () => {
      $("ollama-settings-details").open = true;
    });
  }

  if ($("nim-send")) $("nim-send").addEventListener("click", sendNvidiaNimPrompt);
  if ($("nim-prompt")) $("nim-prompt").addEventListener("keydown", (event) => { if (event.key === "Enter" && event.ctrlKey) { event.preventDefault(); sendNvidiaNimPrompt(); } });
  if ($("nim-stop")) $("nim-stop").addEventListener("click", () => window.abraxius.nvidiaNim.cancel(nvidiaNimState.activeSessionId));
  if ($("nim-clear")) $("nim-clear").addEventListener("click", () => { $("nim-chat-container").innerHTML = '<div id="nim-welcome" class="ollama-welcome-msg"><div class="ollama-welcome-title">NVIDIA NIM Workspace</div><p>Stream Nemotron reasoning and answers through NVIDIA’s OpenAI-compatible API.</p></div>'; $("nim-reasoning").textContent = "Reasoning will appear here…"; });
  if ($("nim-save-key")) $("nim-save-key").addEventListener("click", async () => { await window.abraxius.nvidiaNim.saveSettings({ apiKey: $("nim-api-key")?.value.trim(), endpoint: $("nim-endpoint")?.value.trim(), model: $("nim-model-select")?.value, temperature: Number($("nim-temperature")?.value || 1), topP: Number($("nim-top-p")?.value || 0.95), maxTokens: Number($("nim-max-tokens")?.value || 16384), reasoningBudget: Number($("nim-reasoning-budget")?.value || 16384) }); if ($("nim-api-key")) $("nim-api-key").value = ""; await refreshNvidiaNimWorkspace(); notice("NVIDIA NIM settings encrypted and saved for Abraxius."); });
  if ($("nim-clear-key")) $("nim-clear-key").addEventListener("click", async () => { if (!window.confirm("Clear the NVIDIA NIM API key from this session?")) return; await window.abraxius.nvidiaNim.saveSettings({ clearApiKey: true }); await refreshNvidiaNimWorkspace(); });
  if ($("openrouter-filter-select")) $("openrouter-filter-select").addEventListener("change", refreshOpenRouterWorkspace);
  if ($("openrouter-refresh-models")) $("openrouter-refresh-models").addEventListener("click", refreshOpenRouterWorkspace);
  if ($("openrouter-cancel-retry")) {
    $("openrouter-cancel-retry").addEventListener("click", async () => {
      hideOpenRouterRetryBanner();
      if (openRouterState.activeSessionId && window.abraxius?.openrouter) {
        await window.abraxius.openrouter.cancel(openRouterState.activeSessionId);
      }
    });
  }
  if ($("openrouter-save-key")) $("openrouter-save-key").addEventListener("click", async () => {
    await window.abraxius.openrouter.saveSettings({
      apiKey: $("openrouter-api-key")?.value.trim(),
      endpoint: $("openrouter-endpoint")?.value.trim(),
      temperature: Number($("openrouter-temperature")?.value || 0.7),
      maxRetries: Number($("openrouter-max-retries")?.value || 3),
      maxBackoffSeconds: Number($("openrouter-max-backoff")?.value || 30),
      useMemory: $("openrouter-use-memory")?.checked !== false,
      allowActions: $("openrouter-allow-actions")?.checked === true,
      yoloMode: $("openrouter-yolo-mode")?.checked === true,
      selectedModel: $("openrouter-model-select")?.value,
    });
    if ($("openrouter-api-key")) $("openrouter-api-key").value = "";
    await refreshOpenRouterWorkspace();
    notice("OpenRouter settings encrypted and saved for Abraxius.");
  });
  if ($("openrouter-clear-key")) $("openrouter-clear-key").addEventListener("click", async () => {
    if (!window.confirm("Clear the OpenRouter API key from this session?")) return;
    await window.abraxius.openrouter.saveSettings({ clearApiKey: true });
    await refreshOpenRouterWorkspace();
  });
  if ($("openrouter-model-select")) $("openrouter-model-select").addEventListener("change", () => window.abraxius.openrouter.saveSettings({ selectedModel: $("openrouter-model-select").value }));
  if ($("openrouter-send")) $("openrouter-send").addEventListener("click", () => sendOpenRouterPrompt());
  if ($("openrouter-prompt")) {
    $("openrouter-prompt").addEventListener("input", () => { $("openrouter-prompt").style.height = "auto"; $("openrouter-prompt").style.height = `${Math.min(Math.max($("openrouter-prompt").scrollHeight, 36), 120)}px`; });
    $("openrouter-prompt").addEventListener("keydown", (event) => { if (event.key === "Enter" && event.ctrlKey) { event.preventDefault(); sendOpenRouterPrompt(); } });
  }
  if ($("openrouter-stop")) $("openrouter-stop").addEventListener("click", () => {
    hideOpenRouterRetryBanner();
    if (window.abraxius?.openrouter) window.abraxius.openrouter.cancel(openRouterState.activeSessionId);
  });
  if ($("openrouter-yolo-mode")) $("openrouter-yolo-mode").addEventListener("change", (event) => {
    if (event.target.checked && !window.confirm("Enable YOLO mode? OpenRouter may perform write tools without asking for each action.")) event.target.checked = false;
    if (event.target.checked) appendOpenRouterActivity("⚠ YOLO mode enabled for this session");
  });
  if ($("openrouter-clear")) $("openrouter-clear").addEventListener("click", () => { hideOpenRouterRetryBanner(); openRouterState.messages = []; const container = $("openrouter-chat-container"); if (container) container.innerHTML = `<div class="ollama-welcome-msg" id="openrouter-welcome"><div class="ollama-welcome-title">OpenRouter Workspace</div><p>Connect a key to chat with hosted models while Abraxius keeps private memories local.</p></div>`; if ($("openrouter-activity")) $("openrouter-activity").textContent = "OpenRouter activity will appear here…"; });
  refreshOpenRouterWorkspace();
  refreshNvidiaNimWorkspace();
});

/* ==========================================================================
   Abraxius Memory Core Renderer Module
   ========================================================================== */


let memoryState = {
  health: null,
  records: [],
  proposed: [],
  brief: null,
  settings: null,
};

function escapeHtml(str) {
  if (typeof str !== "string") return "";
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

async function refreshMemoryCore() {
  if (!window.abraxius || !window.abraxius.memory) return;

  try {
    const health = await window.abraxius.memory.health().catch(() => null);
    memoryState.health = health;

    if (health) {
      const countEl = document.getElementById("mem-count-total");
      if (countEl) countEl.textContent = `${health.totalMemories || 0} Memories`;

      const proposedEl = document.getElementById("mem-count-proposed");
      if (proposedEl) proposedEl.textContent = `${health.proposedCount || 0} Proposed`;

      const badgeEl = document.getElementById("mem-review-badge");
      if (badgeEl) badgeEl.textContent = String(health.proposedCount || 0);

      const embedEl = document.getElementById("mem-embed-status");
      if (embedEl) embedEl.textContent = health.embeddingProvider === "ollama" ? "Ollama" : "Keyword";

      const mcpEl = document.getElementById("mem-mcp-status");
      if (mcpEl && health.mcpServer) mcpEl.textContent = `:${health.mcpServer.port}/mcp`;
    }

    // Fetch Records
    const recRes = await window.abraxius.memory.records().catch(() => ({ records: [] }));
    memoryState.records = recRes.records || [];
    renderMemoryCards(memoryState.records);

    // Fetch Proposed
    const propRes = await window.abraxius.memory.proposed().catch(() => ({ proposed: [] }));
    memoryState.proposed = propRes.proposed || [];
    renderProposedCards(memoryState.proposed);

    // Fetch Brief
    const brief = await window.abraxius.memory.brief().catch(() => null);
    memoryState.brief = brief;
    renderProjectBrief(brief);

    // Fetch Settings
    const settings = await window.abraxius.memory.getSettings().catch(() => null);
    memoryState.settings = settings;
    if (settings) populateMemorySettings(settings);

  } catch (err) {
    console.error("Failed to refresh Memory Core UI:", err);
  }
}

function renderMemoryCards(records = []) {
  const container = document.getElementById("mem-cards-list");
  if (!container) return;

  if (records.length === 0) {
    container.innerHTML = `<div class="mem-section-desc">No durable memories found. Add one with + Add Memory or via MCP tools.</div>`;
    return;
  }

  container.innerHTML = records.map((rec) => {
    const scopeClass = `scope-${rec.scope || "project"}`;
    const statusClass = `status-${rec.verificationStatus || "verified"}`;
    const tagsHtml = (rec.tags || []).map((t) => `<span class="mem-tag">#${t}</span>`).join(" ");

    return `
      <article class="mem-card" data-id="${rec.id}">
        <div class="mem-card-head">
          <h3 class="mem-card-title">${escapeHtml(rec.summary)}</h3>
          <div class="mem-badges">
            <span class="mem-badge ${scopeClass}">${rec.scope || "project"}</span>
            <span class="mem-badge ${statusClass}">${rec.verificationStatus || "verified"}</span>
          </div>
        </div>
        <div class="mem-card-content">${escapeHtml(rec.content)}</div>
        <div class="mem-tags-row">${tagsHtml}</div>
        <div class="mem-card-actions">
          <button class="secondary" onclick="handleMemoryCorrect('${rec.id}')">Correct</button>
          <button class="danger" onclick="handleMemoryForget('${rec.id}')">Forget</button>
        </div>
      </article>
    `;
  }).join("");
}

function renderProposedCards(proposed = []) {
  const container = document.getElementById("mem-proposed-list");
  if (!container) return;

  if (proposed.length === 0) {
    container.innerHTML = `<div class="mem-section-desc">No proposed memories pending review. Extraction engine is monitoring task history.</div>`;
    return;
  }

  container.innerHTML = proposed.map((rec) => {
    return `
      <article class="mem-card" data-id="${rec.id}">
        <div class="mem-card-head">
          <h3 class="mem-card-title">${escapeHtml(rec.summary)}</h3>
          <div class="mem-badges">
            <span class="mem-badge status-proposed">Proposed (${Math.round((rec.confidence || 0.7) * 100)}%)</span>
          </div>
        </div>
        <div class="mem-card-content">${escapeHtml(rec.content)}</div>
        <div class="mem-card-actions">
          <button class="primary" onclick="handleApproveProposed('${rec.id}')">Approve</button>
          <button class="secondary" onclick="handleMemoryCorrect('${rec.id}')">Correct</button>
          <button class="danger" onclick="handleRejectProposed('${rec.id}')">Reject</button>
        </div>
      </article>
    `;
  }).join("");
}

function renderProjectBrief(brief) {
  const container = document.getElementById("mem-brief-container");
  if (!container) return;

  if (!brief) {
    container.innerHTML = `<div class="mem-section-desc">No project brief available.</div>`;
    return;
  }

  const renderSection = (title, items) => {
    if (!items || items.length === 0) return "";
    const listHtml = items.map((i) => `<li><strong>${escapeHtml(i.summary)}:</strong> ${escapeHtml(i.content)}</li>`).join("");
    return `
      <div class="mem-brief-card">
        <h3>${title} (${items.length})</h3>
        <ul>${listHtml}</ul>
      </div>
    `;
  };

  const sections = [
    renderSection("Project Facts", brief.facts),
    renderSection("Architectural Decisions", brief.decisions),
    renderSection("Requirements", brief.requirements),
    renderSection("Known Issues & Failures", brief.issues),
    renderSection("Confirmed Fixes", brief.fixes),
    renderSection("Pending Tasks", brief.pendingTasks),
  ].filter(Boolean).join("");

  container.innerHTML = sections || `<div class="mem-section-desc">No brief records for this project yet.</div>`;
}

function populateMemorySettings(settings) {
  const enabledEl = document.getElementById("mem-set-enabled");
  if (enabledEl) enabledEl.checked = settings.enabled !== false;

  const autoEl = document.getElementById("mem-set-autoreview");
  if (autoEl) autoEl.checked = settings.autoReview === true;

  const embedEl = document.getElementById("mem-set-embed-provider");
  if (embedEl) embedEl.value = settings.embeddingProvider || "ollama";

  const hostEl = document.getElementById("mem-set-ollama-host");
  if (hostEl) hostEl.value = settings.ollamaHost || "http://127.0.0.1:11434";

  const modelEl = document.getElementById("mem-set-ollama-model");
  if (modelEl) modelEl.value = settings.ollamaModel || "nomic-embed-text";

  const policyEl = document.getElementById("mem-set-cloud-policy");
  if (policyEl) policyEl.value = settings.cloudPolicy || "never_cloud";

  const portEl = document.getElementById("mem-set-mcp-port");
  if (portEl) portEl.value = settings.mcpPort || 8765;

  const lanEl = document.getElementById("mem-set-mcp-lan");
  if (lanEl) lanEl.checked = settings.allowLan === true;
}

// Global Event Handlers for Memory Core Buttons
window.handleApproveProposed = async function(id) {
  if (!window.abraxius?.memory) return;
  await window.abraxius.memory.approve(id);
  refreshMemoryCore();
};

window.handleRejectProposed = async function(id) {
  if (!window.abraxius?.memory) return;
  await window.abraxius.memory.reject(id);
  refreshMemoryCore();
};

window.handleMemoryForget = async function(id) {
  if (!window.abraxius?.memory) return;
  if (confirm("Are you sure you want to forget this memory?")) {
    await window.abraxius.memory.forget(id);
    refreshMemoryCore();
  }
};

window.handleMemoryCorrect = async function(id) {
  if (!window.abraxius?.memory) return;
  const newContent = prompt("Enter corrected memory content:");
  if (newContent && newContent.trim()) {
    const reason = prompt("Reason for correction (optional):") || "User correction";
    await window.abraxius.memory.correct({ id, newContent: newContent.trim(), reason });
    refreshMemoryCore();
  }
};

// Initialize Subtabs and Search Filters
document.addEventListener("DOMContentLoaded", () => {
  // Subtab switching
  document.querySelectorAll(".mem-subnav").forEach((btn) => {
    btn.addEventListener("click", () => {
      document.querySelectorAll(".mem-subnav").forEach((b) => b.classList.remove("active"));
      document.querySelectorAll(".mem-tab-content").forEach((c) => c.classList.remove("active"));

      btn.classList.add("active");
      const targetId = `mem-tab-${btn.dataset.subtab}`;
      const targetContent = document.getElementById(targetId);
      if (targetContent) targetContent.classList.add("active");
    });
  });

  // Search input handler
  const searchInput = document.getElementById("mem-search-query");
  if (searchInput) {
    let timeout;
    searchInput.addEventListener("input", () => {
      clearTimeout(timeout);
      timeout = setTimeout(async () => {
        const query = searchInput.value.trim();
        if (query && window.abraxius?.memory) {
          const res = await window.abraxius.memory.search(query);
          renderMemoryCards(res.records || []);
        } else {
          renderMemoryCards(memoryState.records);
        }
      }, 250);
    });
  }

  // Add Memory Modal/Prompt
  const addBtn = document.getElementById("mem-open-add-modal");
  if (addBtn) {
    addBtn.addEventListener("click", async () => {
      const content = prompt("Enter durable memory content:");
      if (!content || !content.trim()) return;

      const summary = prompt("Enter 1-line summary (optional):") || content.slice(0, 100);
      const scope = prompt("Scope (global, project, session, private):", "project") || "project";
      const type = prompt("Type (preference, project_fact, requirement, technical_decision, known_issue, failed_attempt, successful_fix, procedure, pending_task):", "project_fact") || "project_fact";

      try {
        await window.abraxius.memory.add({
          content: content.trim(),
          summary: summary.trim(),
          scope,
          type,
        });
        refreshMemoryCore();
      } catch (err) {
        alert(`Failed to add memory: ${err.message}`);
      }
    });
  }

  // Save Settings Button
  const saveSetBtn = document.getElementById("mem-save-settings-btn");
  if (saveSetBtn) {
    saveSetBtn.addEventListener("click", async () => {
      const settings = {
        enabled: document.getElementById("mem-set-enabled").checked,
        autoReview: document.getElementById("mem-set-autoreview").checked,
        embeddingProvider: document.getElementById("mem-set-embed-provider").value,
        ollamaHost: document.getElementById("mem-set-ollama-host").value.trim(),
        ollamaModel: document.getElementById("mem-set-ollama-model").value.trim(),
        cloudPolicy: document.getElementById("mem-set-cloud-policy").value,
        mcpPort: Number(document.getElementById("mem-set-mcp-port").value || 8765),
        allowLan: document.getElementById("mem-set-mcp-lan").checked,
      };

      try {
        await window.abraxius.memory.saveSettings(settings);
        alert("Memory Core settings saved successfully!");
        refreshMemoryCore();
      } catch (err) {
        alert(`Failed to save settings: ${err.message}`);
      }
    });
  }

  // Index Directory Button
  const indexBtn = document.getElementById("mem-index-dir-btn");
  if (indexBtn) {
    indexBtn.addEventListener("click", async () => {
      const dirPath = document.getElementById("mem-index-dir-input").value.trim();
      if (!dirPath) {
        alert("Please enter a directory path.");
        return;
      }

      const statusBox = document.getElementById("mem-index-status");
      if (statusBox) statusBox.textContent = `Indexing approved directory: ${dirPath}...`;

      try {
        const res = await window.abraxius.memory.indexDir(dirPath);
        if (statusBox) {
          statusBox.textContent = `Indexing Complete!\nTotal files: ${res.result.totalFiles}\nIndexed files: ${res.result.indexedFiles}\nSkipped: ${res.result.skippedFiles}`;
        }
        refreshMemoryCore();
      } catch (err) {
        if (statusBox) statusBox.textContent = `Indexing Error: ${err.message}`;
      }
    });
  }

  // Initial load
  refreshMemoryCore();
});

/* ==========================================================================
   PtyWorkspaceManager Implementation
   ========================================================================== */

class PtyWorkspaceManager {
  constructor() {
    this.sessions = new Map();
    this.tabs = [
      { id: "agy-default", name: "Antigravity CLI", kind: "AGY", command: "agy", status: "running" }
    ];
    this.activeTabId = "agy-default";
    this.layout = "single";
    this.focusedPaneIndex = 1;
    this.paneSessions = { 1: "agy-default", 2: null };
    this.composerMode = "llm";
    this.savedPresets = ["npm run dev", "cargo check", "abraxius pull", "ollama list"];
    this.activityLog = [];
    this.pane2Terminal = null;
    this.pane2FitAddon = null;
    this.pane2SearchAddon = null;

    this.init();
  }

  async init() {
    this.setupListeners();
    this.setupSecondPaneTerminal();
    await this.refreshSessions();
    this.renderTabs();
    this.setupComposer();
    this.setupQuickActions();
    this.setupCommandPalette();
    this.setupContextMenu();
    this.setupKeyboardShortcuts();
    this.setupResizer();
  }

  setupSecondPaneTerminal() {
    if (!$("pane-2-terminal")) return;
    this.pane2Terminal = new Terminal({
      convertEol: true,
      cursorBlink: true,
      cursorStyle: "bar",
      fontFamily: '"Google Sans Code", monospace',
      fontSize: 14,
      lineHeight: 1.4,
      scrollback: 5000,
      theme: agyTerminal.options.theme,
    });
    this.pane2FitAddon = new FitAddon.FitAddon();
    this.pane2Terminal.loadAddon(this.pane2FitAddon);
    if (typeof SearchAddon !== "undefined" && SearchAddon.SearchAddon) {
      this.pane2SearchAddon = new SearchAddon.SearchAddon();
      this.pane2Terminal.loadAddon(this.pane2SearchAddon);
    }
    if (typeof WebLinksAddon !== "undefined" && WebLinksAddon.WebLinksAddon) {
      this.pane2Terminal.loadAddon(new WebLinksAddon.WebLinksAddon());
    }
    this.pane2Terminal.open($("pane-2-terminal"));

    this.pane2Terminal.onData((data) => {
      const sessionId = this.paneSessions[2];
      if (sessionId) this.writeToSession(sessionId, data);
    });

    $("pane-2-terminal-container")?.addEventListener("click", () => {
      this.focusPane(2);
    });
  }

  async refreshSessions() {
    if (!window.abraxius?.pty?.list) return;
    try {
      const remoteSessions = await window.abraxius.pty.list();
      for (const s of remoteSessions) {
        if (!this.tabs.some((t) => t.id === s.id)) {
          this.tabs.push({
            id: s.id,
            name: s.name || s.command || "Terminal",
            kind: s.kind || "PTY",
            command: s.command,
            status: s.state || "running",
          });
        }
      }
    } catch {}
  }

  renderTabs() {
    const container = $("pty-tabs-scroll");
    if (!container) return;
    container.innerHTML = "";

    this.tabs.forEach((tab) => {
      const tabEl = document.createElement("button");
      tabEl.className = `pty-tab ${tab.id === this.activeTabId ? "active" : ""}`;
      tabEl.dataset.tabId = tab.id;

      const isRunning = tab.status !== "stopped" && tab.status !== "error";
      const dotClass = isRunning ? "online" : "offline";

      tabEl.innerHTML = `
        <span class="status-dot ${dotClass}"></span>
        <span class="pty-tab-name">${escapeHtml(tab.name)}</span>
        <span class="pty-tab-kind">${escapeHtml(tab.kind || "PTY")}</span>
        ${tab.id !== "agy-default" ? `<span class="pty-tab-close" data-close-id="${tab.id}">&times;</span>` : ""}
      `;

      tabEl.addEventListener("click", (e) => {
        if (e.target.classList.contains("pty-tab-close")) {
          e.stopPropagation();
          this.closeTab(e.target.dataset.closeId);
          return;
        }
        this.switchTab(tab.id);
      });

      container.appendChild(tabEl);
    });

    const activeTab = this.tabs.find((t) => t.id === this.activeTabId);
    if ($("active-session-title")) {
      $("active-session-title").textContent = activeTab ? activeTab.name : "PTY Sessions";
    }
    if ($("composer-target-label")) {
      $("composer-target-label").textContent = `Target: ${activeTab ? activeTab.name : "Active Session"}`;
    }
    if ($("pane-1-title")) {
      $("pane-1-title").textContent = activeTab ? activeTab.name : "Antigravity CLI";
    }
    if ($("pane-1-kind")) {
      $("pane-1-kind").textContent = activeTab ? activeTab.kind : "AGY";
    }
  }

  async switchTab(id) {
    if (!this.tabs.some((t) => t.id === id)) return;
    this.activeTabId = id;
    this.paneSessions[this.focusedPaneIndex] = id;
    this.renderTabs();

    if (id !== "agy-default" && window.abraxius?.pty?.getBuffer) {
      try {
        const buffer = await window.abraxius.pty.getBuffer(id);
        const term = this.focusedPaneIndex === 1 ? agyTerminal : this.pane2Terminal;
        if (term) {
          term.clear();
          term.write(buffer);
        }
      } catch {}
    }

    this.fitTerminals();
  }

  async createPtyTab(options = {}) {
    const defaultName = options.name || (options.command ? options.command.split("/").pop() : "Terminal");
    let session;
    try {
      session = await window.abraxius.pty.create({
        name: defaultName,
        command: options.command,
        args: options.args,
        cwd: options.cwd,
        cols: agyTerminal.cols || 120,
        rows: agyTerminal.rows || 40,
      });
    } catch (err) {
      notice(`Failed to spawn PTY: ${err.message}`);
      return;
    }

    const tabObj = {
      id: session.id,
      name: session.name || defaultName,
      kind: options.command ? "CMD" : "PTY",
      command: session.command,
      status: "running",
    };

    if (!this.tabs.some((t) => t.id === session.id)) {
      this.tabs.push(tabObj);
    }
    await this.switchTab(session.id);
  }

  async closeTab(id) {
    if (id === "agy-default") return;
    try {
      await window.abraxius.pty.close(id);
    } catch {}

    this.tabs = this.tabs.filter((t) => t.id !== id);
    if (this.activeTabId === id) {
      const next = this.tabs[this.tabs.length - 1] || this.tabs[0];
      this.activeTabId = next ? next.id : "agy-default";
    }
    if (this.paneSessions[1] === id) this.paneSessions[1] = this.activeTabId;
    if (this.paneSessions[2] === id) this.paneSessions[2] = null;
    this.renderTabs();
  }

  focusPane(index) {
    this.focusedPaneIndex = index;
    if ($("pane-1")) $("pane-1").classList.toggle("focused", index === 1);
    if ($("pane-2")) $("pane-2").classList.toggle("focused", index === 2);

    const term = index === 1 ? agyTerminal : this.pane2Terminal;
    if (term) term.focus();
  }

  setLayout(mode) {
    this.layout = mode;
    const mainEl = $("agy-workspace-main");
    if (!mainEl) return;

    mainEl.classList.remove("layout-single", "layout-split-h", "layout-split-v");
    mainEl.classList.add(`layout-${mode}`);

    $("pty-split-single-btn")?.classList.toggle("active", mode === "single");
    $("pty-split-h-btn")?.classList.toggle("active", mode === "split-h");
    $("pty-split-v-btn")?.classList.toggle("active", mode === "split-v");

    const pane2 = $("pane-2");
    const resizer = $("pane-resizer");

    if (mode === "single") {
      if (pane2) pane2.style.display = "none";
      if (resizer) resizer.style.display = "none";
    } else {
      if (pane2) pane2.style.display = "flex";
      if (resizer) resizer.style.display = "block";
      if (!this.paneSessions[2]) {
        const otherTab = this.tabs.find((t) => t.id !== this.paneSessions[1]);
        this.paneSessions[2] = otherTab ? otherTab.id : this.paneSessions[1];
      }
    }

    setTimeout(() => this.fitTerminals(), 50);
  }

  fitTerminals() {
    fitAntigravityTerminal();
    if (this.pane2FitAddon && $("pane-2") && $("pane-2").offsetParent !== null) {
      try {
        this.pane2FitAddon.fit();
        const dim = this.pane2Terminal.proposedDimensions;
        const sessionId = this.paneSessions[2];
        if (dim && sessionId && window.abraxius?.pty?.resize) {
          window.abraxius.pty.resize(sessionId, dim.cols, dim.rows).catch(() => {});
        }
      } catch {}
    }
  }

  writeToSession(sessionId, data) {
    if (sessionId === "agy-default") {
      window.abraxius?.antigravity?.write(data)?.catch(() => {});
    } else {
      window.abraxius?.pty?.write(sessionId, data)?.catch(() => {});
    }
  }

  setupListeners() {
    if (window.abraxius?.pty?.onEvent) {
      window.abraxius.pty.onEvent((evt) => {
        if (!evt || !evt.id) return;
        const { id, type, data, state, exitCode } = evt;

        if (type === "output" && data) {
          if (this.paneSessions[1] === id) {
            agyTerminal.write(data);
          }
          if (this.paneSessions[2] === id && this.pane2Terminal) {
            this.pane2Terminal.write(data);
          }
        }

        if (type === "state" || type === "exit") {
          const tab = this.tabs.find((t) => t.id === id);
          if (tab) {
            tab.status = state || (exitCode === 0 ? "stopped" : "error");
            this.renderTabs();
          }
        }
      });
    }

    if (window.abraxius?.pty?.onActivity) {
      window.abraxius.pty.onActivity((act) => {
        this.activityLog.unshift(act);
        this.renderActivityTimeline();
      });
    }
    if (window.abraxius?.pty?.onActivityUpdate) {
      window.abraxius.pty.onActivityUpdate((act) => {
        const item = this.activityLog.find((a) => a.id === act.id);
        if (item) Object.assign(item, act);
        this.renderActivityTimeline();
      });
    }

    $("pty-new-tab-btn")?.addEventListener("click", () => this.createPtyTab());
    $("pty-split-single-btn")?.addEventListener("click", () => this.setLayout("single"));
    $("pty-split-h-btn")?.addEventListener("click", () => this.setLayout("split-h"));
    $("pty-split-v-btn")?.addEventListener("click", () => this.setLayout("split-v"));
    $("close-pane-2")?.addEventListener("click", () => this.setLayout("single"));

    $("pty-activity-toggle-btn")?.addEventListener("click", () => {
      const drawer = $("activity-timeline-drawer");
      if (drawer) drawer.style.display = drawer.style.display === "none" ? "flex" : "none";
    });
    $("close-activity-timeline")?.addEventListener("click", () => {
      if ($("activity-timeline-drawer")) $("activity-timeline-drawer").style.display = "none";
    });

    $("pane-1")?.addEventListener("click", () => this.focusPane(1));
  }

  setupComposer() {
    const chipLlm = $("mode-chip-llm");
    const chipShell = $("mode-chip-shell");

    chipLlm?.addEventListener("click", () => {
      this.composerMode = "llm";
      chipLlm.classList.add("active");
      chipShell?.classList.remove("active");
      $("agy-prompt")?.setAttribute("placeholder", "Prompt Antigravity (e.g. request codebase analysis, run CLI task, edit scripts)…");
    });

    chipShell?.addEventListener("click", () => {
      this.composerMode = "shell";
      chipShell.classList.add("active");
      chipLlm?.classList.remove("active");
      $("agy-prompt")?.setAttribute("placeholder", "Enter shell command (e.g. ls -la, git status, cargo check)…");
    });

    $("composer-save-preset")?.addEventListener("click", () => {
      const val = $("agy-prompt")?.value.trim();
      if (val && !this.savedPresets.includes(val)) {
        this.savedPresets.push(val);
        notice(`Saved preset: "${val}"`);
      }
    });

    $("composer-open-pty")?.addEventListener("click", async () => {
      const val = $("agy-prompt")?.value.trim();
      if (!val) return;
      await this.createPtyTab({ command: "/bin/bash", args: ["-c", val], name: val.slice(0, 16) });
      if ($("agy-prompt")) $("agy-prompt").value = "";
    });
  }

  setupQuickActions() {
    document.querySelectorAll(".quick-action-chip").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const cmd = btn.dataset.cmd;
        if (!cmd) return;

        if (cmd === "npm run dev") {
          await this.createPtyTab({ command: "npm", args: ["run", "dev"], name: "npm dev" });
        } else if (cmd === "cargo check") {
          await this.createPtyTab({ command: "cargo", args: ["check"], name: "cargo check" });
        } else if (cmd === "abraxius pull") {
          showPage("sync");
        } else if (cmd === "ollama list") {
          await this.createPtyTab({ command: "ollama", args: ["list"], name: "ollama list" });
        } else if (cmd === "tail logs") {
          if (window.abraxius?.openLog) window.abraxius.openLog();
        } else if (cmd === "diagnostics") {
          showPage("diagnostics");
        }
      });
    });
  }

  setupCommandPalette() {
    const modal = $("command-palette-modal");
    const input = $("palette-search-input");
    const results = $("palette-results-list");

    const commands = [
      { label: "New PTY Shell", shortcut: "Ctrl+N", action: () => this.createPtyTab() },
      { label: "Split Panes (Horizontal)", shortcut: "Ctrl+\\", action: () => this.setLayout("split-h") },
      { label: "Split Panes (Vertical)", shortcut: "Alt+S", action: () => this.setLayout("split-v") },
      { label: "Single Pane Layout", shortcut: "Alt=1", action: () => this.setLayout("single") },
      { label: "Clear Active Terminal", shortcut: "Ctrl+L", action: () => agyTerminal.clear() },
      { label: "Find in Terminal", shortcut: "Ctrl+F", action: () => $("agy-toggle-search")?.click() },
      { label: "Run npm test", action: () => this.createPtyTab({ command: "npm", args: ["test"], name: "npm test" }) },
      { label: "Run cargo check", action: () => this.createPtyTab({ command: "cargo", args: ["check"], name: "cargo check" }) },
      { label: "Pull from Roblox Studio", action: () => showPage("sync") },
      { label: "Open Ollama Local Models", action: () => showPage("ollama") },
      { label: "Open Memory Core Hive Mind", action: () => showPage("memory") },
      { label: "Toggle Sidebar Rail", action: () => $("rail-collapse-btn")?.click() },
      { label: "Open Host Logs", action: () => window.abraxius?.openLog?.() },
    ];

    const openPalette = () => {
      if (!modal) return;
      modal.style.display = "flex";
      if (input) {
        input.value = "";
        input.focus();
      }
      renderResults(commands);
    };

    const closePalette = () => {
      if (modal) modal.style.display = "none";
    };

    const renderResults = (items) => {
      if (!results) return;
      results.innerHTML = items.length
        ? items.map((item, idx) => `
            <div class="palette-item ${idx === 0 ? "selected" : ""}" data-idx="${idx}">
              <span>${escapeHtml(item.label)}</span>
              ${item.shortcut ? `<kbd>${escapeHtml(item.shortcut)}</kbd>` : ""}
            </div>
          `).join("")
        : '<div class="palette-item" style="color: var(--text-muted);">No matching commands</div>';

      results.querySelectorAll(".palette-item").forEach((el, idx) => {
        el.addEventListener("click", () => {
          items[idx]?.action();
          closePalette();
        });
      });
    };

    $("open-command-palette")?.addEventListener("click", openPalette);

    modal?.addEventListener("click", (e) => {
      if (e.target === modal) closePalette();
    });

    input?.addEventListener("input", (e) => {
      const q = e.target.value.toLowerCase().trim();
      const filtered = commands.filter((c) => c.label.toLowerCase().includes(q));
      renderResults(filtered);
    });

    input?.addEventListener("keydown", (e) => {
      if (e.key === "Escape") closePalette();
      if (e.key === "Enter") {
        const selected = results?.querySelector(".palette-item.selected");
        if (selected) {
          const idx = Number(selected.dataset.idx);
          const item = commands[idx];
          if (item) {
            item.action();
            closePalette();
          }
        }
      }
    });
  }

  setupContextMenu() {
    const menu = $("terminal-context-menu");
    if (!menu) return;

    const showMenu = (e) => {
      e.preventDefault();
      menu.style.display = "flex";
      menu.style.left = `${Math.min(e.clientX, window.innerWidth - 200)}px`;
      menu.style.top = `${Math.min(e.clientY, window.innerHeight - 250)}px`;
    };

    const hideMenu = () => {
      menu.style.display = "none";
    };

    $("agy-terminal-container")?.addEventListener("contextmenu", showMenu);
    $("pane-2-terminal-container")?.addEventListener("contextmenu", showMenu);
    document.addEventListener("click", hideMenu);

    $("ctx-copy")?.addEventListener("click", () => {
      const term = this.focusedPaneIndex === 1 ? agyTerminal : this.pane2Terminal;
      if (term && term.hasSelection()) {
        navigator.clipboard.writeText(term.getSelection());
      }
    });

    $("ctx-paste")?.addEventListener("click", async () => {
      try {
        const text = await navigator.clipboard.readText();
        if (text) {
          const sessionId = this.paneSessions[this.focusedPaneIndex];
          if (sessionId) this.writeToSession(sessionId, text);
        }
      } catch {}
    });

    $("ctx-clear")?.addEventListener("click", () => {
      const term = this.focusedPaneIndex === 1 ? agyTerminal : this.pane2Terminal;
      term?.clear();
    });

    $("ctx-search")?.addEventListener("click", () => {
      $("agy-toggle-search")?.click();
    });

    $("ctx-font-up")?.addEventListener("click", () => {
      const term = this.focusedPaneIndex === 1 ? agyTerminal : this.pane2Terminal;
      if (term) term.options.fontSize = (term.options.fontSize || 14) + 1;
    });

    $("ctx-font-down")?.addEventListener("click", () => {
      const term = this.focusedPaneIndex === 1 ? agyTerminal : this.pane2Terminal;
      if (term) term.options.fontSize = Math.max(10, (term.options.fontSize || 14) - 1);
    });

    $("ctx-select-all")?.addEventListener("click", () => {
      const term = this.focusedPaneIndex === 1 ? agyTerminal : this.pane2Terminal;
      term?.selectAll();
    });
  }

  setupKeyboardShortcuts() {
    window.addEventListener("keydown", (e) => {
      if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key.toUpperCase() === "N") {
        e.preventDefault();
        this.createPtyTab();
      }
      if ((e.ctrlKey || e.metaKey) && e.key === "\\") {
        e.preventDefault();
        this.setLayout(this.layout === "single" ? "split-h" : "single");
      }
      if ((e.ctrlKey || e.metaKey) && e.key.toUpperCase() === "P") {
        e.preventDefault();
        $("open-command-palette")?.click();
      }
      if ((e.ctrlKey || e.metaKey) && e.key.toUpperCase() === "L" && !e.shiftKey) {
        const activeElem = document.activeElement;
        if (activeElem && (activeElem.tagName === "INPUT" || activeElem.tagName === "TEXTAREA")) return;
        e.preventDefault();
        const term = this.focusedPaneIndex === 1 ? agyTerminal : this.pane2Terminal;
        term?.clear();
      }
      if (e.altKey && e.key >= "1" && e.key <= "9") {
        e.preventDefault();
        const idx = Number(e.key) - 1;
        if (this.tabs[idx]) {
          this.switchTab(this.tabs[idx].id);
        }
      }
      if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key.toUpperCase() === "W") {
        e.preventDefault();
        if (this.activeTabId !== "agy-default") {
          this.closeTab(this.activeTabId);
        }
      }
    });
  }

  setupResizer() {
    const resizer = $("pane-resizer");
    const wrapper = $("workspace-panes-wrapper");
    if (!resizer || !wrapper) return;

    let isDragging = false;

    resizer.addEventListener("mousedown", () => {
      isDragging = true;
      resizer.classList.add("dragging");
      document.body.style.userSelect = "none";
    });

    document.addEventListener("mousemove", (e) => {
      if (!isDragging) return;
      const rect = wrapper.getBoundingClientRect();
      if (this.layout === "split-h") {
        const offset = e.clientX - rect.left;
        const pct = Math.max(15, Math.min(85, (offset / rect.width) * 100));
        $("pane-1").style.flex = `0 0 ${pct}%`;
        $("pane-2").style.flex = `0 0 ${100 - pct}%`;
      } else if (this.layout === "split-v") {
        const offset = e.clientY - rect.top;
        const pct = Math.max(15, Math.min(85, (offset / rect.height) * 100));
        $("pane-1").style.flex = `0 0 ${pct}%`;
        $("pane-2").style.flex = `0 0 ${100 - pct}%`;
      }
      this.fitTerminals();
    });

    document.addEventListener("mouseup", () => {
      if (isDragging) {
        isDragging = false;
        resizer.classList.remove("dragging");
        document.body.style.userSelect = "";
        this.fitTerminals();
      }
    });
  }

  renderActivityTimeline() {
    const container = $("activity-timeline-list");
    if (!container) return;
    container.innerHTML = this.activityLog.length
      ? this.activityLog.map((act) => `
          <div class="timeline-card">
            <div class="timeline-card-header">
              <span class="timeline-tag">${escapeHtml(act.sessionName || act.sessionId)}</span>
              <span class="timeline-time">${new Date(act.timestamp).toLocaleTimeString()}</span>
            </div>
            <div class="timeline-cmd">${escapeHtml(act.command)}</div>
            <div style="font-size: 10px; color: ${act.status === "success" ? "var(--ok)" : act.status === "error" ? "var(--bad)" : "var(--warn)"}; margin-top: 4px;">
              ${escapeHtml(act.status.toUpperCase())} ${act.durationMs ? `(${act.durationMs}ms)` : ""}
            </div>
          </div>
        `).join("")
      : '<div class="timeline-empty">No PTY activities logged yet.</div>';
  }
}

document.addEventListener("DOMContentLoaded", () => {
  window.ptyWorkspaceManager = new PtyWorkspaceManager();
});

const fs = require("fs");
const path = require("path");

const MEMORY_DIR = ".abraxius";
const MEMORY_FILE = "memory.json";
const MEMORY_VERSION = 1;

function resolveProjectDir(projectDir) {
  return path.resolve(projectDir || process.cwd());
}

function memoryPath(projectDir) {
  return path.join(resolveProjectDir(projectDir), MEMORY_DIR, MEMORY_FILE);
}

function ensureMemory(projectDir) {
  const file = memoryPath(projectDir);
  const dir = path.dirname(file);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  if (!fs.existsSync(file)) {
    fs.writeFileSync(
      file,
      JSON.stringify({ version: MEMORY_VERSION, updatedAt: Date.now(), notes: [] }, null, 2),
    );
  }
  return file;
}

function loadMemory(projectDir) {
  const file = memoryPath(projectDir);
  if (!fs.existsSync(file)) {
    return { version: MEMORY_VERSION, updatedAt: null, notes: [] };
  }
  const memory = JSON.parse(fs.readFileSync(file, "utf8"));
  return {
    version: memory.version || MEMORY_VERSION,
    updatedAt: memory.updatedAt || null,
    notes: Array.isArray(memory.notes) ? memory.notes : [],
  };
}

function saveMemory(projectDir, memory) {
  const file = ensureMemory(projectDir);
  const next = {
    version: MEMORY_VERSION,
    updatedAt: Date.now(),
    notes: Array.isArray(memory.notes) ? memory.notes : [],
  };
  fs.writeFileSync(file, JSON.stringify(next, null, 2));
  return next;
}

function addMemory(projectDir, note) {
  const text = String(note.text || "").trim();
  if (!text) throw new Error("Memory text is required");
  const memory = loadMemory(projectDir);
  const entry = {
    id: `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`,
    time: Date.now(),
    text,
    tags: Array.isArray(note.tags) ? note.tags.map(String).filter(Boolean) : [],
    path: note.path || null,
    source: note.source || "user",
  };
  memory.notes.unshift(entry);
  return { memory: saveMemory(projectDir, memory), entry };
}

function clearMemory(projectDir, id) {
  if (!id) {
    return saveMemory(projectDir, { notes: [] });
  }
  const memory = loadMemory(projectDir);
  memory.notes = memory.notes.filter((note) => note.id !== id);
  return saveMemory(projectDir, memory);
}

function formatTime(ms) {
  if (!ms) return "never";
  return new Date(ms).toISOString();
}

function compactPending(pushes) {
  return pushes.map((push) => ({
    path: push.path,
    status: push.status,
    stale: push.stale,
    pushedAt: push.pushedAt,
    verifiedAt: push.verifiedAt,
    error: push.error,
  }));
}

function buildAiContext(options = {}) {
  const {
    context,
    pendingPushes,
    pluginServer,
    projectDir,
    noteLimit = 20,
    eventLimit = 20,
  } = options;
  const resolvedProjectDir = resolveProjectDir(projectDir || context?.projectDir);
  const memory = loadMemory(resolvedProjectDir);
  const snapshot = context?.toSnapshot ? context.toSnapshot() : {};
  const pending = pendingPushes?.list ? compactPending(pendingPushes.list()) : [];
  const pluginStatus = pluginServer
    ? {
        connected: pluginServer.isConnected(),
        sessionId: pluginServer.session?.id || null,
        lastSeenAt: pluginServer.session?.lastSeenAt || null,
      }
    : null;
  const pluginEvents = pluginServer?.listEvents
    ? pluginServer.listEvents({ limit: eventLimit })
    : [];

  return {
    generatedAt: Date.now(),
    projectDir: resolvedProjectDir,
    memoryPath: memoryPath(resolvedProjectDir),
    memory: {
      updatedAt: memory.updatedAt,
      notes: memory.notes.slice(0, noteLimit),
    },
    context: snapshot,
    pendingPushes: pending,
    plugin: pluginStatus,
    recentPluginEvents: pluginEvents,
  };
}

function toMarkdown(aiContext) {
  const lines = [];
  lines.push("# Abraxius AI Context");
  lines.push("");
  lines.push(`Generated: ${formatTime(aiContext.generatedAt)}`);
  lines.push(`Project: ${aiContext.projectDir}`);
  lines.push(`Memory file: ${aiContext.memoryPath}`);
  lines.push("");

  lines.push("## Pinned Memory");
  const notes = aiContext.memory.notes;
  if (notes.length === 0) {
    lines.push("- No pinned memory yet. Add durable facts with `mcp remember \"...\"`.");
  } else {
    for (const note of notes) {
      const tags = note.tags.length ? ` [${note.tags.join(", ")}]` : "";
      const target = note.path ? ` (${note.path})` : "";
      lines.push(`- ${note.text}${target}${tags}`);
    }
  }
  lines.push("");

  lines.push("## Active Session");
  lines.push(`- Preferred DataModel: ${aiContext.context.preferredDatamodel || "unknown"}`);
  lines.push(`- Current DataModel: ${aiContext.context.currentDatamodel || "unknown"}`);
  lines.push(`- Project dir: ${aiContext.context.projectDir || aiContext.projectDir}`);
  const studio = aiContext.context.studio || {};
  lines.push(`- Active script: ${studio.activeScriptPath || studio.activeScript?.path || "none"}`);
  const selection = studio.selectionPaths || (studio.selection || []).map((item) => item.path);
  lines.push(`- Selection: ${selection.length ? selection.join(", ") : "none"}`);
  lines.push("");

  lines.push("## Studio Activity Summary");
  const eventCounts = aiContext.context.studioEventCounts || {};
  const countEntries = Object.entries(eventCounts).sort((a, b) => b[1] - a[1]);
  if (countEntries.length === 0) lines.push("- No Studio activity recorded.");
  for (const [type, count] of countEntries) lines.push(`- ${type}: ${count}`);
  const errors = aiContext.context.recentStudioErrors || [];
  for (const error of errors.slice(0, 5)) lines.push(`- Error: ${error.message}`);
  lines.push("");

  lines.push("## Recent Scripts");
  const scripts = aiContext.context.recentScripts || [];
  if (scripts.length === 0) lines.push("- None recorded.");
  for (const script of scripts) lines.push(`- ${script}`);
  lines.push("");

  lines.push("## Recent Operations");
  const operations = aiContext.context.recentOperations || [];
  if (operations.length === 0) lines.push("- None recorded.");
  for (const op of operations) {
    const target = op.target ? ` ${op.target}` : "";
    const summary = op.summary ? ` - ${op.summary}` : "";
    lines.push(`- ${formatTime(op.time)} ${op.op}${target}${summary}`);
  }
  lines.push("");

  lines.push("## Pending Studio Pushes");
  if (aiContext.pendingPushes.length === 0) lines.push("- None.");
  for (const push of aiContext.pendingPushes) {
    const stale = push.stale === null ? "unverified" : push.stale ? "stale" : "live";
    const error = push.error ? ` error=${push.error}` : "";
    lines.push(`- ${push.path}: ${push.status} (${stale})${error}`);
  }
  lines.push("");

  lines.push("## Companion Plugin");
  if (!aiContext.plugin) {
    lines.push("- Plugin server unavailable.");
  } else {
    lines.push(`- Connected: ${aiContext.plugin.connected}`);
    lines.push(`- Session: ${aiContext.plugin.sessionId || "none"}`);
    lines.push(`- Last seen: ${formatTime(aiContext.plugin.lastSeenAt)}`);
  }
  lines.push("");

  lines.push("## Recent Studio Events");
  if (aiContext.recentPluginEvents.length === 0) lines.push("- None recorded.");
  for (const event of aiContext.recentPluginEvents) {
    const subject = event.path || (event.paths ? event.paths.join(", ") : "");
    lines.push(`- #${event.id} ${formatTime(event.time)} ${event.type}${subject ? `: ${subject}` : ""}`);
  }
  lines.push("");

  lines.push("## How To Use This");
  lines.push("- Treat pinned memory as durable project facts unless the user corrects it.");
  lines.push("- Treat recent operations and events as short-term context that may be stale.");
  lines.push("- Check pending pushes before assuming Studio has committed local edits.");

  return `${lines.join("\n")}\n`;
}

module.exports = {
  MEMORY_DIR,
  MEMORY_FILE,
  memoryPath,
  loadMemory,
  addMemory,
  clearMemory,
  buildAiContext,
  toMarkdown,
};

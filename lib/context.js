const fs = require("fs");
const path = require("path");
const { loadProject } = require("./project");

class MCPContext {
  constructor(options = {}) {
    this.maxRecent = options.maxRecent || 32;
    this.stateTtlMs = options.stateTtlMs || 5000;
    this.recent = [];
    this.scripts = [];
    this.cache = new Map();
    this.projectDir = options.projectDir || null;
    this.preferredDatamodel = options.preferredDatamodel || "Edit";
    this.lastStudioState = null;
    this.lastStateAt = 0;
    this.currentDatamodel = null;
    this.studioContext = null;
    this.studioEventCounts = {};
    this.recentStudioEvents = [];
    this.recentStudioErrors = [];
  }

  setProjectDir(dir) {
    this.projectDir = dir ? path.resolve(dir) : null;
  }

  getProject() {
    if (!this.projectDir) return null;
    return loadProject(this.projectDir);
  }

  record(op) {
    const entry = {
      time: Date.now(),
      op: op.type,
      target: op.target || null,
      datamodel: op.datamodel || this.preferredDatamodel,
      summary: op.summary || null,
    };
    this.recent.unshift(entry);
    if (this.recent.length > this.maxRecent) {
      this.recent.length = this.maxRecent;
    }
  }

  touchScript(scriptPath) {
    this.scripts = this.scripts.filter((p) => p !== scriptPath);
    this.scripts.unshift(scriptPath);
    if (this.scripts.length > this.maxRecent) {
      this.scripts.length = this.maxRecent;
    }
  }

  recentScripts(limit = 10) {
    return this.scripts.slice(0, limit);
  }

  lastOperation(type) {
    return this.recent.find((e) => e.op === type) || null;
  }

  setStudioState(state) {
    this.lastStudioState = state;
    this.lastStateAt = Date.now();
    const current = this._extractCurrentDatamodel(state);
    if (current) {
      this.currentDatamodel = current;
      this.preferredDatamodel = current;
    }
  }

  getStudioState() {
    if (!this.lastStudioState) return null;
    if (Date.now() - this.lastStateAt > this.stateTtlMs) return null;
    return this.lastStudioState;
  }

  resolveDatamodel(requested) {
    if (requested) return requested;
    const state = this.getStudioState();
    const current = this._extractCurrentDatamodel(state);
    if (current) return current;
    return this.preferredDatamodel;
  }

  _extractCurrentDatamodel(state) {
    if (!state) return null;
    if (state.current_data_model) return state.current_data_model;
    try {
      const text = state.content[0].text;
      const match = text.match(/Current Studio Mode:\s*(\w+)/);
      if (match) return match[1];
    } catch {}
    return null;
  }

  normalizePath(inputPath) {
    let p = String(inputPath || "").trim();
    if (!p) return null;
    p = p.replace(/^[\/\\]+/, "");
    if (p.toLowerCase().startsWith("game.")) p = p.slice(5);
    return p;
  }

  ingestStudioEvent(event) {
    if (!event || typeof event !== "object") return;
    const type = String(event.type || "unknown");
    this.studioEventCounts[type] = (this.studioEventCounts[type] || 0) + 1;
    if (type === "context_snapshot" && event.snapshot) {
      this.studioContext = event.snapshot;
      this.currentDatamodel = event.snapshot.mode || this.currentDatamodel;
    } else {
      this.recentStudioEvents.unshift(event);
      if (this.recentStudioEvents.length > this.maxRecent) {
        this.recentStudioEvents.length = this.maxRecent;
      }
      if (!this.studioContext) this.studioContext = {};
      if (type === "selection_changed") this.studioContext.selectionPaths = event.paths || [];
      if (type === "active_script_changed") this.studioContext.activeScriptPath = event.path || null;
      if (type === "mode_changed") {
        this.studioContext.mode = event.mode;
        this.currentDatamodel = event.mode || this.currentDatamodel;
      }
      if (type === "hierarchy_changed") this.studioContext.lastHierarchyChange = event;
      if (type === "history") this.studioContext.lastHistoryCommit = event;
    }

    if (type === "source_changed" && event.path) this.touchScript(event.path);
    if (type === "output" && event.level === "MessageError") {
      this.recentStudioErrors.unshift(event);
      if (this.recentStudioErrors.length > 20) this.recentStudioErrors.length = 20;
    }
  }

  getCache(key) {
    const item = this.cache.get(key);
    if (!item) return undefined;
    if (Date.now() > item.expiresAt) {
      this.cache.delete(key);
      return undefined;
    }
    return item.value;
  }

  setCache(key, value, ttlMs = 30000) {
    this.cache.set(key, { value, expiresAt: Date.now() + ttlMs });
  }

  invalidate(prefix) {
    for (const key of this.cache.keys()) {
      if (key.startsWith(prefix)) this.cache.delete(key);
    }
  }

  toSnapshot() {
    return {
      projectDir: this.projectDir,
      preferredDatamodel: this.preferredDatamodel,
      currentDatamodel: this.currentDatamodel,
      recentScripts: this.recentScripts(10),
      recentOperations: this.recent.slice(0, 10),
      studio: this.studioContext,
      studioEventCounts: this.studioEventCounts,
      recentStudioEvents: this.recentStudioEvents.slice(0, 20),
      recentStudioErrors: this.recentStudioErrors.slice(0, 10),
    };
  }
}

module.exports = { MCPContext };

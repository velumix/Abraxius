const crypto = require("crypto");

function hashSource(source) {
  return crypto.createHash("sha256").update(source || "").digest("hex").slice(0, 16);
}

class PendingPushes {
  constructor(options = {}) {
    this.maxAgeMs = options.maxAgeMs || 24 * 60 * 60 * 1000;
    this.entries = new Map();
  }

  recordPush(studioPath, source) {
    const now = Date.now();
    this.entries.set(studioPath, {
      path: studioPath,
      source,
      sourceHash: hashSource(source),
      pushedAt: now,
      status: "pending",
      verifiedAt: null,
      stale: null,
      error: null,
    });
    this._gc();
    return this.entries.get(studioPath);
  }

  verify(studioPath, currentSource) {
    const entry = this.entries.get(studioPath);
    if (!entry) return null;

    const currentHash = hashSource(currentSource);
    entry.verifiedAt = Date.now();
    entry.stale = currentHash !== entry.sourceHash;
    entry.status = entry.stale ? "stale" : "live";
    return entry;
  }

  markCommitted(studioPath) {
    const entry = this.entries.get(studioPath);
    if (!entry) return null;
    entry.status = "committed";
    entry.verifiedAt = Date.now();
    entry.stale = false;
    return entry;
  }

  setError(studioPath, error) {
    const entry = this.entries.get(studioPath);
    if (!entry) return null;
    entry.status = "error";
    entry.error = String(error);
    return entry;
  }

  list() {
    this._gc();
    return Array.from(this.entries.values()).sort((a, b) => b.pushedAt - a.pushedAt);
  }

  get(studioPath) {
    return this.entries.get(studioPath) || null;
  }

  clear(studioPath) {
    if (studioPath) {
      return this.entries.delete(studioPath);
    }
    this.entries.clear();
    return true;
  }

  _gc() {
    const cutoff = Date.now() - this.maxAgeMs;
    for (const [path, entry] of this.entries) {
      if (entry.pushedAt < cutoff) {
        this.entries.delete(path);
      }
    }
  }
}

module.exports = { PendingPushes, hashSource };

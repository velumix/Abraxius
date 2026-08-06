const fs = require("fs");
const path = require("path");
const {
  createMemoryRecord,
  detectSecrets,
} = require("./model");

class MemoryStore {
  constructor(options = {}) {
    this.storageDir = options.storageDir || path.join(process.cwd(), ".abraxius");
    this.storageFile = options.storageFile || path.join(this.storageDir, "memory_store.json");
    this.records = new Map();
    this.docMeta = new Map(); // docPath -> { hash, mtime, lastIndexedAt, chunkIds: [] }
    this.initialized = false;
  }

  ensureInitialized() {
    if (this.initialized) return;
    this.load();
    this.initialized = true;
  }

  load() {
    try {
      if (!fs.existsSync(this.storageDir)) {
        fs.mkdirSync(this.storageDir, { recursive: true });
      }
      if (fs.existsSync(this.storageFile)) {
        const raw = fs.readFileSync(this.storageFile, "utf8");
        const data = JSON.parse(raw);
        if (Array.isArray(data.records)) {
          for (const rec of data.records) {
            this.records.set(rec.id, rec);
          }
        }
        if (data.docMeta && typeof data.docMeta === "object") {
          for (const [k, v] of Object.entries(data.docMeta)) {
            this.docMeta.set(k, v);
          }
        }
      }
    } catch (err) {
      console.error("[AbraxiusMemoryStore] Failed to load store, starting fresh:", err.message);
    }
  }

  save() {
    try {
      if (!fs.existsSync(this.storageDir)) {
        fs.mkdirSync(this.storageDir, { recursive: true });
      }
      const data = {
        version: 1,
        updatedAt: Date.now(),
        records: Array.from(this.records.values()),
        docMeta: Object.fromEntries(this.docMeta.entries()),
      };

      const tmpFile = `${this.storageFile}.tmp.${Date.now()}`;
      fs.writeFileSync(tmpFile, JSON.stringify(data, null, 2), "utf8");
      fs.renameSync(tmpFile, this.storageFile);
    } catch (err) {
      console.error("[AbraxiusMemoryStore] Failed to save store:", err.message);
    }
  }

  addRecord(input = {}) {
    this.ensureInitialized();
    const record = createMemoryRecord(input);
    this.records.set(record.id, record);
    this.save();
    return record;
  }

  getRecord(id) {
    this.ensureInitialized();
    return this.records.get(id) || null;
  }

  updateRecord(id, updates = {}) {
    this.ensureInitialized();
    const existing = this.records.get(id);
    if (!existing) {
      throw new Error(`Memory record ${id} not found.`);
    }

    if (updates.content !== undefined) {
      const secretCheck = detectSecrets(updates.content);
      if (secretCheck.detected) {
        throw new Error(`Secret detected in updated content (${secretCheck.patternName}). Update rejected.`);
      }
    }

    const updated = {
      ...existing,
      ...updates,
      id: existing.id, // ID cannot change
      createdAt: existing.createdAt, // CreatedAt cannot change
      updatedAt: Date.now(),
    };

    if (updates.tags && Array.isArray(updates.tags)) {
      updated.tags = updates.tags.map((t) => String(t).trim().toLowerCase()).filter(Boolean);
    }

    this.records.set(id, updated);
    this.save();
    return updated;
  }

  supersedeRecord(id, newRecordInput = {}) {
    this.ensureInitialized();
    const oldRecord = this.records.get(id);
    if (!oldRecord) {
      throw new Error(`Memory record ${id} to supersede was not found.`);
    }

    // Create the new record linked to oldRecord
    const newRecord = createMemoryRecord({
      ...oldRecord,
      ...newRecordInput,
      id: undefined, // Fresh ID for replacement
      supersedesId: id,
      verificationStatus: newRecordInput.verificationStatus || "verified",
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    // Mark old record as superseded
    oldRecord.verificationStatus = "superseded";
    oldRecord.updatedAt = Date.now();

    this.records.set(id, oldRecord);
    this.records.set(newRecord.id, newRecord);
    this.save();

    return { oldRecord, newRecord };
  }

  forgetRecord(id, options = {}) {
    this.ensureInitialized();
    if (options.confirm !== true) {
      throw new Error("Destructive operation 'forgetRecord' requires explicit confirmation ({ confirm: true }).");
    }
    const existing = this.records.get(id);
    if (!existing) {
      return false;
    }
    this.records.delete(id);
    this.save();
    return true;
  }

  getHistory(id) {
    this.ensureInitialized();
    const history = [];
    let current = this.records.get(id);
    const visited = new Set();

    while (current && !visited.has(current.id)) {
      history.push(current);
      visited.add(current.id);
      if (current.supersedesId) {
        current = this.records.get(current.supersedesId);
      } else {
        break;
      }
    }
    return history;
  }

  cleanExpiredSessions() {
    this.ensureInitialized();
    const now = Date.now();
    let cleaned = 0;
    for (const [id, rec] of this.records.entries()) {
      if (rec.scope === "session" && rec.expiresAt && rec.expiresAt <= now) {
        this.records.delete(id);
        cleaned++;
      }
    }
    if (cleaned > 0) {
      this.save();
    }
    return cleaned;
  }

  listRecords(filter = {}) {
    this.ensureInitialized();
    this.cleanExpiredSessions();

    let list = Array.from(this.records.values());

    if (filter.scope) {
      list = list.filter((r) => r.scope === filter.scope);
    }
    if (filter.projectId) {
      list = list.filter((r) => r.scope === "global" || r.projectId === filter.projectId);
    }
    if (filter.type) {
      list = list.filter((r) => r.type === filter.type);
    }
    if (filter.verificationStatus) {
      list = list.filter((r) => r.verificationStatus === filter.verificationStatus);
    } else if (filter.excludeSupersededAndDisputed !== false) {
      list = list.filter((r) => r.verificationStatus !== "superseded" && r.verificationStatus !== "disputed");
    }
    if (filter.sensitivity) {
      list = list.filter((r) => r.sensitivity === filter.sensitivity);
    }
    if (filter.tag) {
      const tagLower = String(filter.tag).toLowerCase();
      list = list.filter((r) => r.tags && r.tags.includes(tagLower));
    }
    if (filter.sourceType) {
      list = list.filter((r) => r.sourceType === filter.sourceType);
    }

    return list.sort((a, b) => b.updatedAt - a.updatedAt);
  }

  // Document Chunk Indexing Metadata
  getDocMeta(docPath) {
    this.ensureInitialized();
    return this.docMeta.get(docPath) || null;
  }

  saveDocChunks(docPath, hash, mtime, chunks = []) {
    this.ensureInitialized();
    const meta = this.docMeta.get(docPath) || { chunkIds: [] };

    // Remove old chunk records if re-indexing
    for (const chunkId of meta.chunkIds) {
      this.records.delete(chunkId);
    }

    const newChunkIds = [];
    for (const chunk of chunks) {
      const rec = this.addRecord({
        ...chunk,
        sourceType: "document_index",
        sourceReference: chunk.sourceReference || docPath,
      });
      newChunkIds.push(rec.id);
    }

    this.docMeta.set(docPath, {
      hash,
      mtime,
      lastIndexedAt: Date.now(),
      chunkIds: newChunkIds,
    });
    this.save();
  }

  clear() {
    this.records.clear();
    this.docMeta.clear();
    this.save();
  }
}

module.exports = { MemoryStore };

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { detectSecrets } = require("./model");

/**
 * Directories and file patterns to strictly ignore
 */
const DEFAULT_IGNORED_DIRS = new Set([
  ".git",
  ".svn",
  ".hg",
  ".obsidian/plugins",
  "node_modules",
  "build",
  "dist",
  "out",
  ".next",
  "target",
  "vendor",
  "coverage",
]);

const IGNORED_EXTENSIONS = new Set([
  ".exe", ".dll", ".so", ".dylib", ".bin", ".zip", ".tar", ".gz", ".7z",
  ".png", ".jpg", ".jpeg", ".gif", ".ico", ".pdf", ".mp4", ".mp3", ".wav",
  ".sqlite", ".db", ".env", ".key", ".pem", ".p12",
]);

function computeFileHash(filePath) {
  try {
    const buffer = fs.readFileSync(filePath);
    return crypto.createHash("sha256").update(buffer).digest("hex");
  } catch {
    return null;
  }
}

class DocumentIndexer {
  constructor(options = {}) {
    this.store = options.store;
    this.approvedDirectories = new Set(
      (options.approvedDirectories || []).map((d) => path.resolve(d))
    );
  }

  addApprovedDirectory(dirPath) {
    const resolved = path.resolve(dirPath);
    if (!fs.existsSync(resolved)) {
      throw new Error(`Directory does not exist: ${dirPath}`);
    }
    const stat = fs.statSync(resolved);
    if (!stat.isDirectory()) {
      throw new Error(`Path is not a directory: ${dirPath}`);
    }
    this.approvedDirectories.add(resolved);
  }

  removeApprovedDirectory(dirPath) {
    this.approvedDirectories.delete(path.resolve(dirPath));
  }

  isPathApproved(targetPath) {
    const resolved = path.resolve(targetPath);
    for (const appDir of this.approvedDirectories) {
      if (resolved === appDir || resolved.startsWith(appDir + path.sep)) {
        return true;
      }
    }
    return false;
  }

  async indexApprovedDirectories() {
    const results = { totalFiles: 0, indexedFiles: 0, skippedFiles: 0, errors: [] };
    for (const dir of this.approvedDirectories) {
      try {
        const res = await this.indexDirectory(dir);
        results.totalFiles += res.totalFiles;
        results.indexedFiles += res.indexedFiles;
        results.skippedFiles += res.skippedFiles;
        results.errors.push(...res.errors);
      } catch (err) {
        results.errors.push(`Failed to index ${dir}: ${err.message}`);
      }
    }
    return results;
  }

  async indexDirectory(dirPath) {
    const resolvedDir = path.resolve(dirPath);
    if (!this.isPathApproved(resolvedDir)) {
      throw new Error(`Path ${dirPath} is not in the approved directory list.`);
    }

    const results = { totalFiles: 0, indexedFiles: 0, skippedFiles: 0, errors: [] };
    const walk = async (currentDir) => {
      let entries = [];
      try {
        entries = fs.readdirSync(currentDir, { withFileTypes: true });
      } catch (err) {
        results.errors.push(`Cannot read directory ${currentDir}: ${err.message}`);
        return;
      }

      for (const entry of entries) {
        const fullPath = path.join(currentDir, entry.name);
        if (entry.isDirectory()) {
          if (DEFAULT_IGNORED_DIRS.has(entry.name) || entry.name.startsWith(".")) {
            continue;
          }
          await walk(fullPath);
        } else if (entry.isFile()) {
          results.totalFiles++;
          const ext = path.extname(entry.name).toLowerCase();
          if (IGNORED_EXTENSIONS.has(ext)) {
            results.skippedFiles++;
            continue;
          }
          // Focus on markdown & text files
          if (ext === ".md" || ext === ".txt" || ext === ".markdown") {
            try {
              const res = await this.indexFile(fullPath);
              if (res.updated) {
                results.indexedFiles++;
              } else {
                results.skippedFiles++;
              }
            } catch (err) {
              results.errors.push(`Error indexing file ${fullPath}: ${err.message}`);
            }
          } else {
            results.skippedFiles++;
          }
        }
      }
    };

    await walk(resolvedDir);
    return results;
  }

  async indexFile(filePath) {
    const resolvedFile = path.resolve(filePath);
    if (!this.isPathApproved(resolvedFile)) {
      throw new Error(`File ${filePath} is not within an approved directory.`);
    }

    const stat = fs.statSync(resolvedFile);
    const hash = computeFileHash(resolvedFile);
    if (!hash) {
      return { updated: false, reason: "hash_failed" };
    }

    // Check if file was already indexed with same hash & mtime
    const existingMeta = this.store ? this.store.getDocMeta(resolvedFile) : null;
    if (existingMeta && existingMeta.hash === hash && existingMeta.mtime === stat.mtimeMs) {
      return { updated: false, reason: "unchanged" };
    }

    const text = fs.readFileSync(resolvedFile, "utf8");

    // Secret Guard - skip indexing if file contains secret patterns
    const secretCheck = detectSecrets(text);
    if (secretCheck.detected) {
      console.warn(`[DocumentIndexer] Secret detected in file ${resolvedFile} (${secretCheck.patternName}). Skipping document.`);
      return { updated: false, reason: "secret_detected" };
    }

    const chunks = this.chunkMarkdown(text, resolvedFile);
    if (this.store) {
      this.store.saveDocChunks(resolvedFile, hash, stat.mtimeMs, chunks);
    }

    return { updated: true, chunkCount: chunks.length };
  }

  chunkMarkdown(text, filePath) {
    const lines = text.split("\n");
    const chunks = [];
    let currentHeading = "Overview";
    let currentLines = [];

    const flushChunk = () => {
      const content = currentLines.join("\n").trim();
      if (content.length > 20) {
        const summary = content.slice(0, 100).replace(/\n/g, " ");
        chunks.push({
          scope: "project",
          type: "project_fact",
          summary: `${currentHeading}: ${summary}`,
          content,
          tags: ["document_chunk", path.basename(filePath, path.extname(filePath)).toLowerCase()],
          sourceType: "document_index",
          sourceReference: `${filePath}#${encodeURIComponent(currentHeading)}`,
          confidence: 0.9,
          verificationStatus: "verified",
          sensitivity: "normal",
        });
      }
      currentLines = [];
    };

    for (const line of lines) {
      const match = line.match(/^#{1,4}\s+(.+)$/);
      if (match) {
        flushChunk();
        currentHeading = match[1].trim();
      } else {
        currentLines.push(line);
      }
    }
    flushChunk();

    return chunks;
  }
}

module.exports = {
  DocumentIndexer,
  DEFAULT_IGNORED_DIRS,
  IGNORED_EXTENSIONS,
};

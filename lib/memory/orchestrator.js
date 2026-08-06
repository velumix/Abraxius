const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { MemoryStore } = require("./store");
const { OllamaEmbeddingProvider, KeywordEmbeddingProvider } = require("./embeddings");
const { MemoryRetrievalEngine } = require("./retrieval");
const { MemoryExtractionEngine } = require("./extraction");
const { DocumentIndexer } = require("./indexer");
const { McpMemoryHttpServer } = require("./mcp-http-server");

const DEFAULT_SETTINGS = {
  enabled: true,
  autoReview: false,
  maxRecalledMemories: 10,
  characterBudget: 4000,
  embeddingProvider: "ollama", // 'ollama' or 'keyword'
  ollamaHost: "http://127.0.0.1:11434",
  ollamaModel: "nomic-embed-text",
  mcpEnabled: true,
  mcpPort: 8765,
  mcpHost: "127.0.0.1",
  allowLan: false,
  mcpAuthToken: "",
  cloudPolicy: "never_cloud", // 'never_cloud', 'local_only', 'allow'
  sessionRetentionMs: 86400000, // 24 hours
  approvedDirectories: [],
};

class MemoryOrchestrator {
  constructor(options = {}) {
    this.baseDir = options.baseDir || path.join(process.cwd(), ".abraxius");
    this.settingsFile = path.join(this.baseDir, "memory_settings.json");
    this.settings = this.loadSettings();

    // 1. Initialize Store
    this.store = new MemoryStore({
      storageDir: this.baseDir,
      storageFile: path.join(this.baseDir, "memory_store.json"),
    });

    // 2. Initialize Embeddings Provider
    this.embeddingProvider = this.createEmbeddingProvider();

    // 3. Initialize Retrieval Engine
    this.retrieval = new MemoryRetrievalEngine({
      store: this.store,
      embeddingProvider: this.embeddingProvider,
      defaultLimit: this.settings.maxRecalledMemories,
      defaultCharacterBudget: this.settings.characterBudget,
    });

    // 4. Initialize Extraction Engine
    this.extraction = new MemoryExtractionEngine({
      store: this.store,
      autoApprove: this.settings.autoReview,
    });

    // 5. Initialize Document Indexer
    this.indexer = new DocumentIndexer({
      store: this.store,
      approvedDirectories: this.settings.approvedDirectories,
    });

    // 6. Initialize MCP HTTP Server
    this.mcpServer = new McpMemoryHttpServer({
      orchestrator: this,
      host: this.settings.mcpHost,
      port: this.settings.mcpPort,
      allowLan: this.settings.allowLan,
      authToken: this.settings.mcpAuthToken,
    });
  }

  loadSettings() {
    try {
      if (fs.existsSync(this.settingsFile)) {
        const raw = fs.readFileSync(this.settingsFile, "utf8");
        const parsed = JSON.parse(raw);
        return { ...DEFAULT_SETTINGS, ...parsed };
      }
    } catch (err) {
      console.warn("[AbraxiusMemoryCore] Failed to load settings, using defaults:", err.message);
    }
    const token = crypto.randomBytes(16).toString("hex");
    const settings = { ...DEFAULT_SETTINGS, mcpAuthToken: token };
    this.saveSettings(settings);
    return settings;
  }

  saveSettings(newSettings = {}) {
    try {
      if (!fs.existsSync(this.baseDir)) {
        fs.mkdirSync(this.baseDir, { recursive: true });
      }
      this.settings = { ...this.settings, ...newSettings };
      fs.writeFileSync(this.settingsFile, JSON.stringify(this.settings, null, 2), "utf8");
    } catch (err) {
      console.error("[AbraxiusMemoryCore] Failed to save settings:", err.message);
    }
  }

  createEmbeddingProvider() {
    if (this.settings.embeddingProvider === "ollama") {
      return new OllamaEmbeddingProvider({
        host: this.settings.ollamaHost,
        model: this.settings.ollamaModel,
      });
    }
    return new KeywordEmbeddingProvider();
  }

  updateSettings(updates = {}) {
    this.saveSettings(updates);
    this.embeddingProvider = this.createEmbeddingProvider();
    this.retrieval.embeddingProvider = this.embeddingProvider;
    this.retrieval.defaultLimit = this.settings.maxRecalledMemories;
    this.retrieval.defaultCharacterBudget = this.settings.characterBudget;
    this.extraction.autoApprove = this.settings.autoReview;
    if (this.mcpServer) {
      this.mcpServer.port = this.settings.mcpPort;
      this.mcpServer.host = this.settings.mcpHost;
      this.mcpServer.allowLan = this.settings.allowLan;
      this.mcpServer.authToken = this.settings.mcpAuthToken;
    }
    return this.settings;
  }

  async start() {
    this.store.ensureInitialized();
    if (this.settings.mcpEnabled) {
      await this.mcpServer.start().catch((err) => {
        console.warn("[AbraxiusMemoryCore] MCP HTTP server startup warning:", err.message);
      });
    }
  }

  async stop() {
    this.mcpServer.stop();
  }

  /**
   * Main Recall API for LLM Pre-Request
   */
  async searchMemories(options = {}) {
    if (!this.settings.enabled) {
      return { records: [], formattedContext: "" };
    }
    return this.retrieval.retrieve({
      ...options,
      cloudPolicy: this.settings.cloudPolicy,
    });
  }

  /**
   * Pre-LLM Request Helper: Injects recalled memory block into system or prompt string
   */
  async injectMemoryContext(prompt, scopeContext = {}) {
    const res = await this.searchMemories({
      query: prompt,
      scopeContext,
      limit: this.settings.maxRecalledMemories,
    });

    if (!res.formattedContext) {
      return prompt;
    }

    return `${res.formattedContext}\n\n${prompt}`;
  }

  /**
   * Post-LLM Task Helper: Optionally extracts durable memories
   */
  async extractTaskMemories(transcriptText, scopeContext = {}) {
    if (!this.settings.enabled) return { extracted: [], added: [], proposed: [] };
    return this.extraction.extractFromTranscript(transcriptText, scopeContext);
  }

  /**
   * Generates a structured Project Brief for the specified project ID
   */
  getProjectBrief(projectId = null) {
    const records = this.store.listRecords({ projectId });
    const brief = {
      projectId: projectId || "global",
      facts: [],
      decisions: [],
      requirements: [],
      issues: [],
      fixes: [],
      pendingTasks: [],
      procedures: [],
    };

    for (const rec of records) {
      switch (rec.type) {
        case "project_fact":
          brief.facts.push(rec);
          break;
        case "technical_decision":
          brief.decisions.push(rec);
          break;
        case "requirement":
          brief.requirements.push(rec);
          break;
        case "known_issue":
        case "failed_attempt":
          brief.issues.push(rec);
          break;
        case "successful_fix":
          brief.fixes.push(rec);
          break;
        case "pending_task":
          brief.pendingTasks.push(rec);
          break;
        case "procedure":
          brief.procedures.push(rec);
          break;
      }
    }

    return brief;
  }

  /**
   * Health metrics and status report
   */
  getHealthStatus() {
    const allRecords = this.store.listRecords({ excludeSupersededAndDisputed: false });
    const proposed = allRecords.filter((r) => r.verificationStatus === "proposed");
    const verified = allRecords.filter((r) => r.verificationStatus === "verified");

    return {
      status: "healthy",
      enabled: this.settings.enabled,
      totalMemories: allRecords.length,
      verifiedCount: verified.length,
      proposedCount: proposed.length,
      approvedDirectoriesCount: this.settings.approvedDirectories.length,
      embeddingProvider: this.settings.embeddingProvider,
      mcpServer: {
        enabled: this.settings.mcpEnabled,
        host: this.settings.mcpHost,
        port: this.settings.mcpPort,
        endpoint: `http://${this.settings.mcpHost}:${this.settings.mcpPort}/mcp`,
      },
      cloudPolicy: this.settings.cloudPolicy,
    };
  }
}

module.exports = { MemoryOrchestrator, DEFAULT_SETTINGS };

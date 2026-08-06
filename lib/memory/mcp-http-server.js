const http = require("http");
const { URL } = require("url");

class McpMemoryHttpServer {
  constructor(options = {}) {
    this.orchestrator = options.orchestrator;
    this.host = options.host || "127.0.0.1";
    this.port = options.port || 8765;
    this.allowLan = options.allowLan || false;
    this.authToken = options.authToken || null;
    this.server = null;
  }

  getToolDefinitions() {
    return [
      {
        name: "memory_search",
        description: "Search durable hive mind memories using hybrid semantic + keyword ranking.",
        inputSchema: {
          type: "object",
          properties: {
            query: { type: "string", description: "Search query text" },
            scope: { type: "string", description: "Filter scope (global, project, agent, session, private)" },
            type: { type: "string", description: "Memory type filter" },
            limit: { type: "number", description: "Max results to return (default 10)" },
            projectId: { type: "string", description: "Project ID context" },
          },
        },
      },
      {
        name: "memory_add",
        description: "Store a new durable memory in the Abraxius Memory Core hive mind.",
        inputSchema: {
          type: "object",
          properties: {
            content: { type: "string", description: "Detailed memory text content" },
            summary: { type: "string", description: "Short 1-line summary" },
            scope: { type: "string", description: "Scope (global, project, agent, session, private)" },
            type: { type: "string", description: "Memory type (preference, project_fact, requirement, technical_decision, known_issue, failed_attempt, successful_fix, procedure, pending_task)" },
            tags: { type: "array", items: { type: "string" }, description: "Tags array" },
            projectId: { type: "string", description: "Project ID" },
            sensitivity: { type: "string", description: "Sensitivity (normal, private)" },
          },
          required: ["content"],
        },
      },
      {
        name: "memory_get",
        description: "Retrieve a specific memory record by its unique UUID.",
        inputSchema: {
          type: "object",
          properties: {
            id: { type: "string", description: "Memory UUID" },
          },
          required: ["id"],
        },
      },
      {
        name: "memory_update",
        description: "Update fields of an existing memory record.",
        inputSchema: {
          type: "object",
          properties: {
            id: { type: "string", description: "Memory UUID" },
            content: { type: "string" },
            summary: { type: "string" },
            type: { type: "string" },
            tags: { type: "array", items: { type: "string" } },
          },
          required: ["id"],
        },
      },
      {
        name: "memory_correct",
        description: "Correct an existing memory, marking the old record superseded and linking history.",
        inputSchema: {
          type: "object",
          properties: {
            id: { type: "string", description: "Memory UUID to correct" },
            newContent: { type: "string", description: "Replacement content" },
            newSummary: { type: "string", description: "Replacement summary" },
            reason: { type: "string", description: "Reason for correction" },
          },
          required: ["id", "newContent"],
        },
      },
      {
        name: "memory_forget",
        description: "Remove a memory record from the store. DESTRUCTIVE: Requires confirm: true.",
        inputSchema: {
          type: "object",
          properties: {
            id: { type: "string", description: "Memory UUID to remove" },
            confirm: { type: "boolean", description: "Must set to true to confirm deletion" },
          },
          required: ["id", "confirm"],
        },
      },
      {
        name: "memory_list_recent",
        description: "List recent active memories.",
        inputSchema: {
          type: "object",
          properties: {
            limit: { type: "number", description: "Number of records" },
            scope: { type: "string" },
            type: { type: "string" },
          },
        },
      },
      {
        name: "memory_list_decisions",
        description: "List architectural and technical decision memories.",
        inputSchema: {
          type: "object",
          properties: {
            limit: { type: "number" },
            scope: { type: "string" },
          },
        },
      },
      {
        name: "memory_list_failed_attempts",
        description: "List recorded failed attempts and bug analysis memories.",
        inputSchema: {
          type: "object",
          properties: {
            limit: { type: "number" },
            scope: { type: "string" },
          },
        },
      },
      {
        name: "memory_get_project_brief",
        description: "Get a comprehensive project brief summarizing facts, decisions, requirements, issues, and tasks.",
        inputSchema: {
          type: "object",
          properties: {
            projectId: { type: "string", description: "Project ID" },
          },
        },
      },
      {
        name: "memory_index_document",
        description: "Index an approved Markdown or text document into memory chunks.",
        inputSchema: {
          type: "object",
          properties: {
            path: { type: "string", description: "File path in approved directory" },
          },
          required: ["path"],
        },
      },
      {
        name: "memory_health",
        description: "Get status and health metrics of Abraxius Memory Core.",
        inputSchema: {
          type: "object",
          properties: {},
        },
      },
    ];
  }

  async handleToolCall(name, args = {}, requestContext = {}) {
    if (!this.orchestrator) {
      throw new Error("Memory orchestrator is not initialized");
    }

    switch (name) {
      case "memory_search": {
        const res = await this.orchestrator.searchMemories({
          query: args.query,
          scopeContext: { scope: args.scope, projectId: args.projectId },
          type: args.type,
          limit: args.limit || 10,
          isLocalModel: requestContext.isLocal !== false,
        });
        return {
          records: res.records,
          count: res.records.length,
          formattedContext: res.formattedContext,
        };
      }

      case "memory_add": {
        const rec = this.orchestrator.store.addRecord({
          content: args.content,
          summary: args.summary,
          scope: args.scope || "project",
          type: args.type || "project_fact",
          tags: args.tags || [],
          projectId: args.projectId || null,
          sensitivity: args.sensitivity || "normal",
          sourceType: "mcp",
        });
        return { ok: true, memory: rec };
      }

      case "memory_get": {
        const rec = this.orchestrator.store.getRecord(args.id);
        if (!rec) throw new Error(`Memory record ${args.id} not found.`);
        return rec;
      }

      case "memory_update": {
        const updated = this.orchestrator.store.updateRecord(args.id, {
          content: args.content,
          summary: args.summary,
          type: args.type,
          tags: args.tags,
        });
        return { ok: true, memory: updated };
      }

      case "memory_correct": {
        const res = this.orchestrator.extraction.correctProposed(
          args.id,
          args.newContent,
          args.newSummary,
          args.reason
        );
        return { ok: true, oldRecord: res.oldRecord, newRecord: res.newRecord };
      }

      case "memory_forget": {
        if (args.confirm !== true) {
          throw new Error("Destructive parameter 'confirm: true' is required to forget memory.");
        }
        const deleted = this.orchestrator.store.forgetRecord(args.id, { confirm: true });
        return { ok: deleted, id: args.id };
      }

      case "memory_list_recent": {
        const list = this.orchestrator.store.listRecords({
          scope: args.scope,
          type: args.type,
        });
        return { records: list.slice(0, args.limit || 15) };
      }

      case "memory_list_decisions": {
        const list = this.orchestrator.store.listRecords({
          scope: args.scope,
          type: "technical_decision",
        });
        return { records: list.slice(0, args.limit || 15) };
      }

      case "memory_list_failed_attempts": {
        const list = this.orchestrator.store.listRecords({
          scope: args.scope,
          type: "failed_attempt",
        });
        return { records: list.slice(0, args.limit || 15) };
      }

      case "memory_get_project_brief": {
        const brief = this.orchestrator.getProjectBrief(args.projectId);
        return brief;
      }

      case "memory_index_document": {
        const res = await this.orchestrator.indexer.indexFile(args.path);
        return res;
      }

      case "memory_health": {
        return this.orchestrator.getHealthStatus();
      }

      default:
        throw new Error(`Unknown MCP memory tool '${name}'`);
    }
  }

  start() {
    if (this.server) return Promise.resolve();

    return new Promise((resolve, reject) => {
      this.server = http.createServer(async (req, res) => {
        const clientIp = req.socket.remoteAddress || "";
        const isLocal =
          clientIp === "127.0.0.1" ||
          clientIp === "::1" ||
          clientIp === "::ffff:127.0.0.1" ||
          clientIp === "localhost";

        // Non-local security check
        if (!isLocal && !this.allowLan) {
          res.writeHead(403, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ error: "LAN access to MCP Memory server is disabled." }));
          return;
        }

        if (!isLocal && this.authToken) {
          const authHeader = req.headers["authorization"] || "";
          if (authHeader !== `Bearer ${this.authToken}`) {
            res.writeHead(401, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ error: "Unauthorized: Invalid Bearer token" }));
            return;
          }
        }

        const parsedUrl = new URL(req.url, `http://${req.headers.host || "127.0.0.1"}`);

        // Health check endpoint
        if (req.method === "GET" && (parsedUrl.pathname === "/health" || parsedUrl.pathname === "/mcp/health")) {
          res.writeHead(200, { "Content-Type": "application/json" });
          res.end(JSON.stringify(this.orchestrator ? this.orchestrator.getHealthStatus() : { status: "ok" }));
          return;
        }

        // Standard MCP JSON-RPC over Streamable HTTP POST endpoint (/mcp or /)
        if (req.method === "POST") {
          let bodyStr = "";
          req.on("data", (chunk) => (bodyStr += chunk));
          req.on("end", async () => {
            try {
              const body = JSON.parse(bodyStr || "{}");
              const { jsonrpc, id, method, params } = body;

              if (method === "initialize") {
                res.writeHead(200, { "Content-Type": "application/json" });
                res.end(
                  JSON.stringify({
                    jsonrpc: "2.0",
                    id,
                    result: {
                      protocolVersion: "2024-11-05",
                      capabilities: { tools: {} },
                      serverInfo: { name: "abraxius-memory-core", version: "1.0.0" },
                    },
                  })
                );
                return;
              }

              if (method === "tools/list") {
                res.writeHead(200, { "Content-Type": "application/json" });
                res.end(
                  JSON.stringify({
                    jsonrpc: "2.0",
                    id,
                    result: { tools: this.getToolDefinitions() },
                  })
                );
                return;
              }

              if (method === "tools/call") {
                const toolName = params?.name;
                const toolArgs = params?.arguments || {};
                try {
                  const toolResult = await this.handleToolCall(toolName, toolArgs, { isLocal });
                  res.writeHead(200, { "Content-Type": "application/json" });
                  res.end(
                    JSON.stringify({
                      jsonrpc: "2.0",
                      id,
                      result: {
                        content: [
                          {
                            type: "text",
                            text: typeof toolResult === "string" ? toolResult : JSON.stringify(toolResult, null, 2),
                          },
                        ],
                      },
                    })
                  );
                } catch (err) {
                  res.writeHead(200, { "Content-Type": "application/json" });
                  res.end(
                    JSON.stringify({
                      jsonrpc: "2.0",
                      id,
                      result: {
                        content: [{ type: "text", text: `Error: ${err.message}` }],
                        isError: true,
                      },
                    })
                  );
                }
                return;
              }

              res.writeHead(400, { "Content-Type": "application/json" });
              res.end(JSON.stringify({ jsonrpc: "2.0", id, error: { code: -32601, message: `Method '${method}' not found` } }));
            } catch (err) {
              res.writeHead(400, { "Content-Type": "application/json" });
              res.end(JSON.stringify({ jsonrpc: "2.0", error: { code: -32700, message: "Parse error" } }));
            }
          });
          return;
        }

        res.writeHead(404, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Not found" }));
      });

      this.server.on("error", (err) => {
        if (err.code === "EADDRINUSE") {
          console.warn(`[McpMemoryHttpServer] Port ${this.port} in use, skipping HTTP listen.`);
          resolve();
        } else {
          reject(err);
        }
      });

      this.server.listen(this.port, this.host, () => {
        console.log(`[AbraxiusMemoryCore] Local MCP Streamable HTTP server listening on http://${this.host}:${this.port}/mcp`);
        resolve();
      });
    });
  }

  stop() {
    if (this.server) {
      this.server.close();
      this.server = null;
    }
  }
}

module.exports = { McpMemoryHttpServer };

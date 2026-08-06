const readline = require("readline");
const { MCPClient } = require("../client");
const { ABRAXIUS_NOTICE } = require("./mcp-notice");
const { OpenRouterClient, DEFAULT_MODEL: DEFAULT_OPENROUTER_MODEL } = require("./openrouter");

class McpStdioServer {
  constructor(options = {}) {
    this.input = options.input || process.stdin;
    this.output = options.output || process.stdout;
    this.client = options.client || new MCPClient();
    this.rl = null;
  }

  start() {
    this.rl = readline.createInterface({
      input: this.input,
      output: null,
      terminal: false,
    });

    this.rl.on("line", async (line) => {
      const trimmed = line.trim();
      if (!trimmed) return;
      let msg;
      try {
        msg = JSON.parse(trimmed);
      } catch (err) {
        this._sendError(null, -32700, "Parse error");
        return;
      }

      await this._handleMessage(msg);
    });

    return this;
  }

  close() {
    if (this.rl) {
      this.rl.close();
      this.rl = null;
    }
  }

  async _handleMessage(msg) {
    if (!msg || typeof msg !== "object") return;
    const { id, method, params } = msg;

    // Notifications (no id)
    if (id === undefined) {
      if (method === "notifications/initialized" || method === "initialized") {
        // Initialized notification, no response required
      }
      return;
    }

    // Requests (with id)
    switch (method) {
      case "initialize":
        this._sendResult(id, {
          protocolVersion: "2024-11-05",
          capabilities: {
            tools: {},
          },
          serverInfo: {
            name: "abraxius-mcp",
            version: "1.1.0",
          },
          instructions: `${ABRAXIUS_NOTICE.description}. ${ABRAXIUS_NOTICE.safetyNotice} Recommended entry point: ${ABRAXIUS_NOTICE.recommendedCommand}. Host: ${ABRAXIUS_NOTICE.prerequisites.daemonHost}`,
        });
        break;

      case "ping":
        this._sendResult(id, {});
        break;

      case "tools/list":
        await this._handleToolsList(id);
        break;

      case "tools/call":
        await this._handleToolsCall(id, params);
        break;

      default:
        this._sendError(id, -32601, `Method '${method}' not found`);
        break;
    }
  }

  async _handleToolsList(id) {
    try {
      const health = await this.client.health();
      if (!health || !health.running) {
        this._sendError(
          id,
          -32603,
          `Abraxius App host is offline (${ABRAXIUS_NOTICE.prerequisites.daemonHost}). Launch Abraxius App (or run 'node server.js start') to enable Studio tools.`,
        );
        return;
      }
      if (!health.connected) {
        this._sendError(
          id,
          -32603,
          "Abraxius daemon is running but Roblox Studio is not connected. Open Roblox Studio with the Abraxius plugin enabled.",
        );
        return;
      }
      const toolsRes = await this.client.tools();
      const studioTools = (toolsRes && toolsRes.tools) || [];

      const { McpMemoryHttpServer } = require("./memory/mcp-http-server");
      const memoryToolDefs = new McpMemoryHttpServer().getToolDefinitions();

      const openRouterTool = {
        name: "openrouter_chat",
        description: "Send a prompt to the configured OpenRouter model. Requires OPENROUTER_API_KEY in the MCP server environment.",
        inputSchema: {
          type: "object",
          properties: {
            prompt: { type: "string", minLength: 1 },
            model: { type: "string" },
          },
          required: ["prompt"],
          additionalProperties: false,
        },
      };

      const allTools = [...studioTools, ...memoryToolDefs, openRouterTool];
      this._sendResult(id, { tools: allTools });
    } catch (err) {
      this._sendError(
        id,
        -32603,
        `Abraxius App host is offline (${ABRAXIUS_NOTICE.prerequisites.daemonHost}): ${err.message}. Launch Abraxius App to enable Studio tools.`,
      );
    }
  }

  async _handleToolsCall(id, params = {}) {
    const { name, arguments: args = {} } = params;
    if (!name) {
      this._sendToolError(id, "Tool call missing 'name' parameter");
      return;
    }

    // Direct routing for Abraxius Memory Core tools
    if (name.startsWith("memory_")) {
      try {
        const { MemoryOrchestrator } = require("./memory");
        const orchestrator = new MemoryOrchestrator();
        const { McpMemoryHttpServer } = require("./memory/mcp-http-server");
        const helper = new McpMemoryHttpServer({ orchestrator });
        const res = await helper.handleToolCall(name, args, { isLocal: true });
        const text = typeof res === "string" ? res : JSON.stringify(res, null, 2);
        this._sendResult(id, { content: [{ type: "text", text }] });
      } catch (err) {
        this._sendToolError(id, `Memory tool error: ${err.message}`);
      }
      return;
    }

    if (name === "openrouter_chat") {
      try {
        if (!process.env.OPENROUTER_API_KEY) throw new Error("OPENROUTER_API_KEY is not configured for the MCP server.");
        if (!args || typeof args.prompt !== "string" || !args.prompt.trim()) throw new Error("prompt is required.");
        const client = new OpenRouterClient({ apiKey: process.env.OPENROUTER_API_KEY, endpoint: process.env.OPENROUTER_ENDPOINT });
        let fullText = "";
        await client.streamChat({
          model: args.model || process.env.OPENROUTER_MODEL || DEFAULT_OPENROUTER_MODEL,
          messages: [{ role: "user", content: args.prompt.trim() }],
          onChunk: (chunk) => { fullText += chunk; },
        });
        this._sendResult(id, { content: [{ type: "text", text: fullText }] });
      } catch (err) {
        this._sendToolError(id, `OpenRouter error: ${err.message}`);
      }
      return;
    }

    try {
      const health = await this.client.health();
      if (!health || !health.running) {
        this._sendToolError(
          id,
          `Abraxius App host is offline (${ABRAXIUS_NOTICE.prerequisites.daemonHost}). Launch Abraxius App to enable Studio tool calls.`,
        );
        return;
      }
      if (!health.connected) {
        this._sendToolError(
          id,
          "Abraxius daemon is running but Roblox Studio is not connected. Open Roblox Studio with the Abraxius plugin enabled.",
        );
        return;
      }

      const res = await this.client.call(name, args);
      const text = typeof res === "string" ? res : JSON.stringify(res, null, 2);
      this._sendResult(id, {
        content: [
          {
            type: "text",
            text,
          },
        ],
      });
    } catch (err) {
      this._sendToolError(
        id,
        `Abraxius App host is offline (${ABRAXIUS_NOTICE.prerequisites.daemonHost}): ${err.message}`,
      );
    }
  }

  _sendResult(id, result) {
    const envelope = {
      jsonrpc: "2.0",
      id,
      result,
    };
    this.output.write(JSON.stringify(envelope) + "\n");
  }

  _sendError(id, code, message) {
    const envelope = {
      jsonrpc: "2.0",
      id,
      error: { code, message },
    };
    this.output.write(JSON.stringify(envelope) + "\n");
  }

  _sendToolError(id, errorMessage) {
    this._sendResult(id, {
      content: [
        {
          type: "text",
          text: `Error: ${errorMessage}`,
        },
      ],
      isError: true,
    });
  }
}

function runMcpStdioServer(options = {}) {
  const server = new McpStdioServer(options);
  return server.start();
}

module.exports = {
  McpStdioServer,
  runMcpStdioServer,
};

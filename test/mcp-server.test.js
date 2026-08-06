const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { PassThrough } = require("node:stream");
const test = require("node:test");
const { execSync } = require("node:child_process");

const root = path.resolve(__dirname, "..");
const { McpStdioServer } = require(path.join(root, "lib", "mcp-server"));
const { ABRAXIUS_NOTICE, getHumanNotice } = require(path.join(root, "lib", "mcp-notice"));
const { buildAiContext, toMarkdown } = require(path.join(root, "lib", "ai-context"));

class MockMCPClient {
  constructor(options = {}) {
    this.isOnline = options.isOnline ?? true;
    this.isConnected = options.isConnected ?? true;
    this.toolList = options.toolList || [
      { name: "get_studio_state", description: "Get studio state" },
      { name: "execute_luau", description: "Execute luau code" },
    ];
    this.callResults = options.callResults || {
      get_studio_state: { DataModel: "Edit", PlaceId: 123456 },
    };
  }

  async health() {
    if (!this.isOnline) {
      throw new Error("Cannot connect to MCP daemon on localhost:13470");
    }
    return {
      running: true,
      connected: this.isConnected,
      uptime: 100,
    };
  }

  async tools() {
    return { tools: this.toolList };
  }

  async call(name, args = {}) {
    if (this.callResults[name]) {
      return this.callResults[name];
    }
    return { ok: true, name, args };
  }
}

async function sendReceive(server, input, output, requestObj) {
  return new Promise((resolve) => {
    let buffer = "";
    const onData = (chunk) => {
      buffer += chunk.toString("utf8");
      if (buffer.includes("\n")) {
        output.removeListener("data", onData);
        const line = buffer.trim();
        resolve(JSON.parse(line));
      }
    };
    output.on("data", onData);
    input.write(JSON.stringify(requestObj) + "\n");
  });
}

test("MCP stdio server protocol framing and initialize handshake", async () => {
  const input = new PassThrough();
  const output = new PassThrough();
  const client = new MockMCPClient();
  const server = new McpStdioServer({ input, output, client }).start();

  const initRes = await sendReceive(server, input, output, {
    jsonrpc: "2.0",
    id: 1,
    method: "initialize",
    params: {
      protocolVersion: "2024-11-05",
      capabilities: {},
      clientInfo: { name: "test-agent", version: "1.0.0" },
    },
  });

  assert.equal(initRes.jsonrpc, "2.0");
  assert.equal(initRes.id, 1);
  assert.ok(initRes.result);
  assert.equal(initRes.result.protocolVersion, "2024-11-05");
  assert.equal(initRes.result.serverInfo.name, "abraxius-mcp");
  assert.match(initRes.result.instructions, /Abraxius/);

  // Ping test
  const pingRes = await sendReceive(server, input, output, {
    jsonrpc: "2.0",
    id: 2,
    method: "ping",
  });
  assert.equal(pingRes.jsonrpc, "2.0");
  assert.equal(pingRes.id, 2);
  assert.deepEqual(pingRes.result, {});

  // Unknown method test
  const unknownRes = await sendReceive(server, input, output, {
    jsonrpc: "2.0",
    id: 3,
    method: "non_existent_method",
  });
  assert.equal(unknownRes.jsonrpc, "2.0");
  assert.equal(unknownRes.id, 3);
  assert.equal(unknownRes.error.code, -32601);

  server.close();
});

test("MCP stdio server tool discovery and forwarding", async () => {
  const input = new PassThrough();
  const output = new PassThrough();
  const client = new MockMCPClient();
  const server = new McpStdioServer({ input, output, client }).start();

  // Test tools/list
  const listRes = await sendReceive(server, input, output, {
    jsonrpc: "2.0",
    id: 10,
    method: "tools/list",
  });

  assert.equal(listRes.jsonrpc, "2.0");
  assert.equal(listRes.id, 10);
  assert.ok(Array.isArray(listRes.result.tools));
  assert.ok(listRes.result.tools.length >= 2);
  assert.equal(listRes.result.tools[0].name, "get_studio_state");

  // Test tools/call
  const callRes = await sendReceive(server, input, output, {
    jsonrpc: "2.0",
    id: 11,
    method: "tools/call",
    params: {
      name: "get_studio_state",
      arguments: {},
    },
  });

  assert.equal(callRes.jsonrpc, "2.0");
  assert.equal(callRes.id, 11);
  assert.ok(Array.isArray(callRes.result.content));
  assert.equal(callRes.result.content[0].type, "text");
  assert.match(callRes.result.content[0].text, /PlaceId/);

  server.close();
});

test("MCP stdio server offline behavior", async () => {
  // 1. Host daemon offline
  {
    const input = new PassThrough();
    const output = new PassThrough();
    const client = new MockMCPClient({ isOnline: false });
    const server = new McpStdioServer({ input, output, client }).start();

    const listRes = await sendReceive(server, input, output, {
      jsonrpc: "2.0",
      id: 20,
      method: "tools/list",
    });

    assert.equal(listRes.jsonrpc, "2.0");
    assert.equal(listRes.id, 20);
    assert.ok(listRes.error);
    assert.match(listRes.error.message, /Abraxius App host is offline/);

    const callRes = await sendReceive(server, input, output, {
      jsonrpc: "2.0",
      id: 21,
      method: "tools/call",
      params: { name: "execute_luau", arguments: { code: "print(1)" } },
    });

    assert.equal(callRes.jsonrpc, "2.0");
    assert.equal(callRes.id, 21);
    assert.equal(callRes.result.isError, true);
    assert.match(callRes.result.content[0].text, /Abraxius App host is offline/);

    server.close();
  }

  // 2. Studio disconnected
  {
    const input = new PassThrough();
    const output = new PassThrough();
    const client = new MockMCPClient({ isOnline: true, isConnected: false });
    const server = new McpStdioServer({ input, output, client }).start();

    const listRes = await sendReceive(server, input, output, {
      jsonrpc: "2.0",
      id: 30,
      method: "tools/list",
    });

    assert.equal(listRes.jsonrpc, "2.0");
    assert.equal(listRes.id, 30);
    assert.ok(listRes.error);
    assert.match(listRes.error.message, /Roblox Studio is not connected/);

    server.close();
  }
});

test("Discovery CLI command and notice output contract", () => {
  const nodeBin = process.execPath;
  const cliPath = path.join(root, "cli.js");

  // Run discovery command
  const rawDiscovery = execSync(`"${nodeBin}" "${cliPath}" discovery`, {
    encoding: "utf8",
  });
  const discovery = JSON.parse(rawDiscovery);

  assert.equal(discovery.abraxius.present, true);
  assert.equal(discovery.abraxius.recommendedCommand, "node cli.js stdio");
  assert.ok(discovery.abraxius.prerequisites.daemonHost);
  assert.ok(discovery.abraxius.safetyNotice.includes("mutations require explicit user intent"));
  assert.match(discovery.notice, /ABRAXIUS MCP NOTICE/);

  // Run status command
  const rawStatus = execSync(`"${nodeBin}" "${cliPath}" status`, {
    encoding: "utf8",
  });
  assert.match(rawStatus, /ABRAXIUS MCP NOTICE/);
  assert.match(rawStatus, /node cli\.js stdio/);
});

test("AI context briefing contains Abraxius MCP notice and safety rule", () => {
  const ctx = buildAiContext({ projectDir: root });
  assert.ok(ctx.abraxiusNotice);
  assert.equal(ctx.abraxiusNotice.present, true);

  const md = toMarkdown(ctx);
  assert.match(md, /Abraxius MCP Notice/);
  assert.match(md, /node cli\.js stdio/);
  assert.match(md, /Roblox Studio script mutations require explicit user intent/);
});

test("Workspace configuration files contract", () => {
  // Check .mcp.json
  const mcpJsonPath = path.join(root, ".mcp.json");
  assert.ok(fs.existsSync(mcpJsonPath), ".mcp.json must exist in root");
  const mcpJson = JSON.parse(fs.readFileSync(mcpJsonPath, "utf8"));
  assert.ok(mcpJson.mcpServers && mcpJson.mcpServers.abraxius);
  assert.equal(mcpJson.mcpServers.abraxius.command, "node");
  assert.deepEqual(mcpJson.mcpServers.abraxius.args, ["cli.js", "stdio"]);

  // Check .agents/abraxius.json
  const agentJsonPath = path.join(root, ".agents", "abraxius.json");
  assert.ok(fs.existsSync(agentJsonPath), ".agents/abraxius.json must exist");
  const agentJson = JSON.parse(fs.readFileSync(agentJsonPath, "utf8"));
  assert.equal(agentJson.present, true);
  assert.equal(agentJson.recommendedCommand, "node cli.js stdio");
});

---
sidebar_position: 6
sidebar_label: MCP Client Setup
---

# Abraxius MCP Client Setup & Discovery

This document provides copy-paste MCP configuration instructions for connecting generic LLM/CLI agents to Abraxius via stdio MCP JSON-RPC.

## Overview

Abraxius exposes a standard stdio MCP server command (`node cli.js stdio`). The stdio server bridges tool calls to the app-owned host (`http://localhost:13470`) and Roblox Studio.

### Prerequisites

1. **Abraxius App Host**: Running on `http://localhost:13470` (start Abraxius App or run `node server.js start`).
2. **Roblox Studio Connection**: Roblox Studio open with the Abraxius companion plugin installed and enabled.
3. **Safety Rule**: Roblox Studio script mutations require explicit user intent and approval. Inspect live state before mutating.

## Machine Discovery

Agents starting in this repository can discover Abraxius capabilities via:
- Discovery command: `node cli.js discovery`
- Workspace configuration: `.mcp.json`
- Agent manifest: `.agents/abraxius.json`
- Briefing command: `node cli.js ai-context`

## Client Configurations

### 1. Workspace Configuration (`.mcp.json`)
Used by Antigravity, Claude Code CLI, Cursor, Windsurf, and generic MCP hosts.

Place this file in your project root or workspace:

```json
{
  "mcpServers": {
    "abraxius": {
      "command": "node",
      "args": ["cli.js", "stdio"]
    }
  }
}
```

### 2. Claude Desktop (`claude_desktop_config.json`)
Add to `~/.config/Claude/claude_desktop_config.json` (Linux) or `%APPDATA%\Claude\claude_desktop_config.json` (Windows):

```json
{
  "mcpServers": {
    "abraxius": {
      "command": "node",
      "args": ["/path/to/Abraxius/cli.js", "stdio"],
      "cwd": "/path/to/Abraxius"
    }
  }
}
```

### 3. Antigravity CLI / AGY (`~/.gemini/antigravity-cli/mcp.json`)

```json
{
  "mcpServers": {
    "abraxius": {
      "command": "node",
      "args": ["cli.js", "stdio"],
      "cwd": "${workspaceFolder}"
    }
  }
}
```

### 4. Codex / Generic MCP CLIs (`config.json` or `config.yaml`)

```json
{
  "mcpServers": {
    "abraxius": {
      "command": "node",
      "args": ["cli.js", "stdio"]
    }
  }
}
```

### Security Note

- The stdio MCP bridge uses local HTTP on loopback (`http://localhost:13470`).
- No bearer tokens or credentials are required or exposed in stdout or documentation.

### Browser AI tool channel

The daemon also exposes a loopback WebSocket channel for browser extensions and
local AI surfaces:

```text
ws://127.0.0.1:13473/ai
```

It accepts `initialize`, `tools/list`, `context/get`, `tools/call`, and `ping`
messages. Read-only calls execute normally. Mutating calls return
`approvalRequired` until the client explicitly repeats the request with
`approved: true`.

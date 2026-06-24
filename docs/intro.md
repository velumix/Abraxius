# Introduction

Abraxius is a background MCP bridge and CLI for Roblox Studio. It replaces the need for `StudioMCP.exe` by listening on the same WebSocket endpoint Roblox Studio already connects to (`ws://localhost:13469/studio`) and exposing a local HTTP API on `localhost:13470`.

## What it does

- **Bridge**: Maintains a persistent WebSocket connection to Roblox Studio and performs the MCP client handshake.
- **HTTP API**: Serves tools, state, Luau execution, and logging endpoints over HTTP so any language can talk to Studio.
- **CLI**: Provides a terminal interface for starting the bridge, calling tools, executing Luau, and syncing scripts.
- **Sync**: Pulls scripts from Studio into a local project and pushes local edits back with Abraxius' focused, two-way script sync workflow.

## Architecture

```
node cli.js  --HTTP-->  node server.js  --WebSocket-->  Roblox Studio
                        (localhost:13470)             (localhost:13469)
```

## Quick start

```bash
npm install
node cli.js start
node cli.js pull ./my-game
node cli.js tools
node cli.js state
```

Roblox Studio must be open with MCP enabled in Assistant Settings.

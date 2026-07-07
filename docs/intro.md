# Introduction

Abraxius is a background MCP bridge and CLI for Roblox Studio. It replaces the need for `StudioMCP.exe` by listening on the same WebSocket endpoint Roblox Studio already connects to (`ws://localhost:13469/studio`) and exposing a local HTTP API on `localhost:13470`.

## What it does

- **Bridge**: Maintains a persistent WebSocket connection to Roblox Studio and performs the MCP client handshake.
- **HTTP API**: Serves tools, state, Luau execution, and logging endpoints over HTTP so any language can talk to Studio.
- **CLI**: Provides a terminal interface for starting the bridge, calling tools, executing Luau, and syncing scripts.
- **AI Context**: Produces one AI-readable briefing with pinned project memory, recent operations, pending pushes, and Studio companion events.
- **Sync**: Pulls scripts from Studio into a local project and pushes local edits back with Abraxius' focused, two-way script sync workflow.
- **Studio Companion Plugin**: A second HTTP channel on `localhost:13471` gives Abraxius live Studio state (selection, source changes, play mode) and makes Draft Mode pushes trackable.

## Architecture

```
node cli.js  --HTTP-->  node server.js  --WebSocket-->  Roblox Studio
                        (localhost:13470)             (localhost:13469)
                        |
                        +--HTTP--> AbraxiusCompanion plugin
                                  (localhost:13471)
```

## Quick start

```bash
npm install
node cli.js start
node cli.js pull ./my-game
node cli.js remember "MatchManager owns round flow." --tag architecture --path ServerScriptService.MatchManager
node cli.js ai-context
node cli.js tools
node cli.js state
```

Roblox Studio must be open with MCP enabled in Assistant Settings.

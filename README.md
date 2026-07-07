# Abraxius

Background MCP bridge + CLI for Roblox Studio with a local-to-Studio script sync workflow.

Abraxius runs a background bridge to Roblox Studio's MCP WebSocket (`ws://localhost:13469/studio`) and exposes a local HTTP API on `localhost:13470` so you can query, edit, and pull scripts from Studio.

The bridge is designed for LLM use: it keeps session context (recent scripts, current DataModel, active project), provides high-level commands that combine multiple MCP calls, and stays alive with heartbeats and auto-reconnect when Studio disconnects.

## Install

```bash
npm install
```

## Documentation

Full documentation is built with [Moonwave](https://github.com/evaera/moonwave).

```bash
# Live development server
npm run docs:dev

# Build static site (outputs to `build/`)
npm run docs:build
```

## Quick start

```bash
# Start the background bridge (auto-starts on first command)
node cli.js start

# Pull all scripts from the open place into a local project
node cli.js pull ./my-game

# List tools
node cli.js tools

# Get studio state
node cli.js state

# Call any MCP tool
node cli.js call search_game_tree '{"path":"Workspace","max_depth":2,"head_limit":20}'
node cli.js call script_read '{"target_file":"ServerScriptService.MatchManager","should_read_entire_file":true}'
node cli.js call multi_edit '{"file_path":"game.ServerScriptService.MatchManager","datamodel_type":"Edit","edits":[{"old_string":"...","new_string":"..."}]}'

# Context-aware smart calls (auto datamodel, records history)
node cli.js smart execute_luau '{"code":"return game.Workspace"}'
node cli.js smart multi_edit '{"file_path":"ServerScriptService.MatchManager","edits":[{"old_string":"...","new_string":"..."}]}'

# High-level edits
node cli.js edit ServerScriptService.MatchManager 'local MAX = 8' 'local MAX = 12'
node cli.js search knife

# Execute Luau
node cli.js execute 'print(#game.Workspace:GetChildren())'

# Stop the bridge
node cli.js stop
```

## Sync workflow

## Pull

`mcp pull <dir>` extracts scripts from the connected Studio instance into a local project. Discovery and reads run in parallel with a small rate limit so large places finish quickly without hammering Studio.

```bash
# Pull everything
node cli.js pull game

# Pull one script
node cli.js pull --target ServerScriptService.MatchManager game

# Pull a list of targets from a file (one Studio path per line)
node cli.js pull --targets-file targets.txt game
```

```
my-game/
├── place.json
└── src/
    ├── ReplicatedStorage/
    │   ├── Config.luau
    │   └── Modules/
    │       └── SomeModule.luau
    ├── ServerScriptService/
    │   ├── MatchManager.server.luau
    │   └── CoinManager.luau
    ├── StarterGui/
    │   └── TrollUI/
    │       └── TrollUIClient.client.luau
    ├── StarterPlayer/
    │   └── StarterPlayerScripts/
    │       └── KnifeClient/
    │           ├── init.client.luau
    │           └── Child.luau
    └── Workspace/
        └── LobbyInteractives/
            └── DoubleVotePad.server.luau
```

File extension conventions:

| Extension | Roblox class |
|---|---|
| `.server.luau` | `Script` |
| `.client.luau` | `LocalScript` |
| `.luau` | `ModuleScript` |
| `init.server.luau` | `Script` with children |
| `init.client.luau` | `LocalScript` with children |
| `init.luau` | `ModuleScript` with children |

`place.json` maps the local tree back to Roblox services:

```json
{
  "name": "my-game",
  "format": "abraxius-v1",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": { "$path": "src/ReplicatedStorage" },
    "ServerScriptService": { "$path": "src/ServerScriptService" }
  }
}
```

## Push

After editing a pulled script locally, push it back to Studio from the project root:

```bash
mcp push game/src/ServerScriptService/MatchManager.server.luau
```

This resolves the local file back to `game.ServerScriptService.MatchManager`, reads the current Studio source, and applies a `multi_edit` with your changes.

## Architecture

```
node cli.js  --HTTP-->  node server.js  --WebSocket-->  Roblox Studio
                        (localhost:13470)             (localhost:13469)
```

- `server.js` listens for Roblox Studio on `ws://localhost:13469/studio` and serves an HTTP API on `localhost:13470`.
- `client.js` talks to the HTTP API.
- `cli.js` is the terminal interface.
- `bridge.js` contains the WebSocket MCP protocol logic.
- `lib/pull.js` + `lib/project.js` handle the local-to-Studio script sync.

## Daemon commands

| Command | Description |
|---|---|
| `start` | Start the bridge in the background |
| `stop` | Stop the background bridge |
| `status` | Check daemon + Studio connection |
| `logs` | Tail daemon log |
| `tools` | List available tools |
| `state` | Get current studio state |
| `call <name> [json]` | Call a tool with JSON arguments |
| `smart <name> [json]` | Context-aware tool call |
| `execute <code>` | Run Luau code |
| `context` | Show session context |
| `context project <dir>` | Set active project directory |
| `context datamodel <dm>` | Set preferred DataModel |
| `ai-context [--json]` | Print an AI-readable briefing with memory and live context |
| `remember <text>` | Pin a durable project fact in `.abraxius/memory.json` |
| `memory` | List pinned project memory |
| `memory clear [id]` | Clear all pinned memory, or one entry |
| `edit <path> <old> <new>` | Read + edit a script in one step |
| `batch <file>` | Run a JSON batch file of tool calls |
| `find-replace <paths-file> <old> <new>` | Find/replace across scripts |
| `search [keywords]` | Smart script search |
| `pull [dir]` | Pull scripts into a local project (default: current dir) |
| `push <file>` | Push a local script file back to Studio |
| `repl` | Interactive shell |
| `plugin events [limit]` | Show recent Studio companion events |
| `plugin selection` | Show current Studio selection via the companion plugin |
| `plugin state` | Show plugin-observed Studio state |
| `plugin call <type> [json]` | Send a raw companion plugin command |

## Companion plugin workflow

Install the Studio plugin, restart Roblox Studio, and make sure HTTP requests are enabled:

```bash
npm run install-plugin
mcp plugin
mcp plugin events 20
mcp plugin selection
mcp plugin state
```

The companion plugin reports selection and script source changes to the daemon. Abraxius keeps a bounded event history, so agents and CLI users can inspect what changed recently without needing to catch the event live.

## AI context and memory

Use pinned memory for durable facts an AI should carry between sessions: architecture decisions, source-of-truth scripts, naming conventions, risky systems, and user preferences.

```bash
mcp remember "MatchManager owns round flow; do not move phase timing into UI clients." --tag architecture --path ServerScriptService.MatchManager
mcp remember "Prefer small focused Luau modules over large manager rewrites." --tag preference
mcp memory
mcp ai-context
```

`mcp ai-context` prints a compact Markdown briefing with pinned memory, recent scripts, recent operations, pending Studio pushes, companion plugin status, and recent Studio events. If the daemon is not running, it still falls back to the local `.abraxius/memory.json` file.

## Programmatic usage

```js
const { MCPClient } = require("./client");
const client = new MCPClient();

const health = await client.health();
const tools = await client.tools();
const state = await client.state();
const result = await client.call("execute_luau", { code: 'print("hi")', datamodel_type: "Edit" });
```

## Global install

```bash
npm install -g .
mcp status
mcp pull ./my-game
mcp call get_studio_state
```

## Notes

- The bridge replaces `StudioMCP.exe`. Do not run both at the same time.
- Roblox Studio must be open with MCP enabled in Assistant Settings.
- `pull` currently extracts scripts and minimal container structure. Non-script instances (Parts, Models, etc.) are skipped to keep the project focused on code.

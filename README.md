# Abraxius

Background MCP bridge + CLI for Roblox Studio with a local-to-Studio script sync workflow.

Abraxius runs a background bridge to Roblox Studio's MCP WebSocket (`ws://localhost:13469/studio`) and exposes a local HTTP API on `localhost:13470` so you can query, edit, and pull scripts from Studio.

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

# Execute Luau
node cli.js execute 'print(#game.Workspace:GetChildren())'

# Stop the bridge
node cli.js stop
```

## Sync workflow

## Pull

`mcp pull <dir>` extracts scripts from the connected Studio instance into a local project. A typical workflow keeps the extracted place in a `game/` folder:

```bash
node cli.js pull game
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
| `execute <code>` | Run Luau code |
| `pull [dir]` | Pull scripts into a local project (default: current dir) |
| `push <file>` | Push a local script file back to Studio |
| `repl` | Interactive shell |

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

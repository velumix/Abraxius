# CLI Reference

The `mcp` command is the main interface for managing the bridge and interacting with Roblox Studio.

## Daemon commands

| Command | Description |
|---|---|
| `start` | Start the bridge daemon in the background |
| `stop` | Stop the background bridge |
| `status` | Check daemon + Studio connection |
| `logs` | Tail daemon log file |

## Query commands

| Command | Description |
|---|---|
| `tools` | List available MCP tools |
| `state` | Get current studio state |
| `call <name> [json]` | Call a tool with JSON arguments |
| `smart <name> [json]` | Context-aware tool call (auto datamodel, records history) |
| `execute <code>` | Execute Luau code in Studio |
| `repl` | Interactive tool-calling shell |
| `context` | Show or set session context |
| `ai-context [--json] [--project <dir>]` | Print one AI-readable briefing |
| `remember <text> [--tag <tag>] [--path <path>]` | Pin a durable project fact |
| `memory` | List pinned project memory |
| `memory clear [id]` | Clear all pinned memory, or one entry |
| `npm run rust:run -- <command>` | Run the Rust control binary |

## Edit commands

| Command | Description |
|---|---|
| `edit <path> <old> <new>` | Read + edit a script in one step |
| `batch <file>` | Run a JSON batch file of tool calls |
| `find-replace <paths-file> <old> <new>` | Find/replace across multiple Studio scripts |
| `search [keywords]` | Smart script search |

## Sync commands

| Command | Description |
|---|---|
| `pull [dir]` | Pull all scripts into a local project (default: current directory) |
| `pull --target <path> [dir]` | Pull one Studio script by path |
| `pull --targets-file <file> [dir]` | Pull a list of Studio paths from a file |
| `push <file>` | Push a local script file back to Studio |

## Draft Mode / companion plugin commands

| Command | Description |
|---|---|
| `plugin` | Show Studio companion plugin connection status |
| `plugin events [limit]` | Show recent companion plugin events |
| `plugin selection` | Show current Explorer selection |
| `plugin state` | Show plugin-observed Studio state |
| `plugin call <type> [json]` | Send a raw command to the companion plugin |
| `pending` | List pushes that are waiting for Studio to commit |
| `pending verify` | Ask the companion plugin which pushes are still stale |
| `pending clear [path]` | Clear pending push record(s) |

## Examples

```bash
# Start the daemon
mcp start

# List tools
mcp tools

# Get studio state
mcp state

# Call a tool
mcp call search_game_tree '{"path":"Workspace","max_depth":2,"head_limit":20}'
mcp call script_read '{"target_file":"ServerScriptService.MatchManager","should_read_entire_file":true}'

# Context-aware call
mcp smart execute_luau '{"code":"return game.Workspace"}'

# Pin durable AI memory and produce a context briefing
mcp remember "MatchManager owns round flow." --tag architecture --path ServerScriptService.MatchManager
mcp memory
mcp ai-context

# Use the Rust extension control binary
npm run rust:check
npm run rust:run -- ai-context

# Execute Luau
mcp execute 'print(#game.Workspace:GetChildren())'

# Pull all scripts into a project
mcp pull ./my-game

# Pull one specific script
mcp pull --target ServerScriptService.MatchManager ./my-game

# Pull a list of targets from a file
mcp pull --targets-file targets.txt ./my-game

# Push an edited script back
mcp push ./my-game/src/ServerScriptService/MatchManager.server.luau

# Install the Studio companion plugin
npm run install-plugin

# See pushes waiting for commit
mcp pending
mcp pending verify

# Inspect Studio companion plugin state
mcp plugin
mcp plugin events 20
mcp plugin selection
mcp plugin call resolve_path '{"path":"ServerScriptService.MatchManager"}'
```

# CLI Reference

Run the Node CLI as `node cli.js <command>`, or install it globally and use
`mcp <command>`. The Rust control binary is available through
`npm run rust:run -- <command>`.

## Daemon

| Command | Description |
|---|---|
| `start` | Start a background daemon when the Windows app is not running |
| `stop` | Stop the active daemon |
| `status` | Read daemon, MCP, and companion health |
| `logs` | Tail the daemon log |

Do not start the Node daemon while Abraxius.App already supervises the Rust
daemon on ports `13469`-`13471`.

## Companion

| Command | Description |
|---|---|
| `plugin` | Show companion session status |
| `plugin events [limit]` | Show recent Studio events |
| `plugin selection` | Read the Explorer selection |
| `plugin state` | Read edit/play mode state |
| `plugin inspect <path>` | List direct children of an instance |
| `plugin select <paths...>` | Select Studio instances |
| `plugin open <path> [line]` | Open a Studio script |
| `plugin call <type> [json]` | Send a raw companion command |

## Sync

| Command | Description |
|---|---|
| `pull [dir]` | Export all scripts through the companion |
| `pull --target <path> [dir]` | Pull one script; requires MCP |
| `pull --targets-file <file> [dir]` | Pull listed targets; requires MCP |
| `push <file>` | Push an existing mapped script through MCP or companion |

```powershell
node cli.js pull game
node cli.js push game\src\ServerScriptService\KnitServer.server.luau
node cli.js plugin call read_source '{"path":"game.ServerScriptService.KnitServer"}'
```

Full pull writes `place.json` and `src/`. Companion push updates existing
scripts and verifies the source by reading it back. New-script creation still
requires MCP.

## MCP-dependent commands

| Command | Description |
|---|---|
| `tools` | List connected MCP tools |
| `state` | Read MCP Studio state |
| `call <name> [json]` | Call an MCP tool |
| `smart <name> [json]` | Make a context-aware MCP call |
| `execute <code>` | Execute Luau through MCP |
| `edit`, `batch`, `find-replace`, `search` | High-level MCP edit helpers |

These commands return a connection error when the legacy MCP bridge is not
connected. Companion commands and full sync remain available independently.

## Context and memory

| Command | Description |
|---|---|
| `context` | Show or set session context |
| `ai-context [--json] [--project <dir>]` | Print an AI briefing |
| `remember <text> [options]` | Pin durable project memory |
| `memory` | List pinned memory |
| `memory clear [id]` | Clear one or all entries |
| `pending` | List tracked pushes |
| `pending verify` | Verify tracked Studio sources |
| `pending clear [path]` | Clear tracked push records |

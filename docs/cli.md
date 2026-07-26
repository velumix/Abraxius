# CLI Reference

AI agents should choose a workflow with [AI Guide: Using
Abraxius](ai-usage.md) before using this complete syntax reference.

Run the Node CLI as `node cli.js <command>`, or install it globally and use
`abraxius <command>`. The earlier `mcp` executable remains as a compatibility
alias. The Rust control binary is available through
`npm run rust:run -- <command>`.

## App host

| Command | Description |
|---|---|
| `start` | Confirm the Abraxius App host is running; otherwise instruct the user to launch it |
| `stop` | Direct lifecycle control back to the app |
| `status` | Read app-host, MCP, and companion health |
| `logs` | Tail the app-supervised host log |

The CLI is always a thin client of Abraxius.App. It never starts the legacy
Node daemon, takes ownership of ports `13469`-`13471`, or shuts down the Rust
host. Start, restart, stop, and quit belong to the app window or tray menu.

## AXL

| Command | Description |
|---|---|
| `axl <text>` | Parse and execute one compact AXL/1 command |
| `axl --file <file>` | Execute exact UTF-8 AXL from a file |
| `axl --stdin` | Read exact AXL from standard input |
| `axl --ast <text>` | Parse and print the typed JSON AST without execution |

See [AXL: Abraxius Exchange Language](axl.md) for the grammar, revision-safe
patch form, compact responses, and currently reserved features.

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
| `plugin call <type> [json]` | Send a raw companion command; supports JSON files/stdin |

## Sync

| Command | Description |
|---|---|
| `pull [dir]` | Export all scripts through the companion |
| `pull --target <path> [dir]` | Pull one script; requires MCP |
| `pull --targets-file <file> [dir]` | Pull listed targets; requires MCP |
| `push <file>` | Push a mapped script through granular MCP `multi_edit` |

```powershell
node cli.js pull game
node cli.js push game\src\ServerScriptService\KnitServer.server.luau
node cli.js plugin call read_source '{"path":"game.ServerScriptService.KnitServer"}'
```

## PowerShell-safe input

Complex JSON and multiline Luau should not be placed directly on a PowerShell
command line. Abraxius reads UTF-8 input from files or standard input before it
parses JSON, so quotes, backslashes, newlines, dollar signs, backticks, and
Unicode reach Studio without a shell escaping round trip.

```powershell
# Safest for generated commands and source-bearing payloads
node cli.js plugin call write_source --json-file .\write-source.json

# A PowerShell here-string can be piped without inline argument quoting
@'
{"path":"game.ServerScriptService.Test","dryRun":true,"source":"print(\"hello\")"}
'@ | node cli.js plugin call write_source --json-stdin

# Multiline Luau stays as exact file content
node cli.js execute --file .\diagnostic.luau
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Get-Content -Encoding UTF8 -Raw .\diagnostic.luau | node cli.js execute --stdin
```

The same `--json-file`, `--json-stdin`, and explicit `--json` inputs work with
`call`, `smart`, and `plugin call` in both the Node and Rust control CLIs.
`execute` accepts `--file`, `--stdin`, and explicit `--text`. JSON command
payloads must be objects, and the `plugin call <type>` positional type cannot be
overridden by a `type` field inside the JSON payload.

For byte-exact Unicode on Windows PowerShell 5.1, prefer `--json-file` or
`--file`. If stdin is required, set `$OutputEncoding` to a BOM-less
`UTF8Encoding` and use `Get-Content -Encoding UTF8 -Raw`; both halves are
required because PowerShell otherwise decodes or emits the text with a legacy
code page.

Full pull writes `place.json` and `src/`. Script push requires MCP plus the
companion: the companion supplies byte-exact reads, while every source mutation
uses atomic `multi_edit` operations. Whole-script fallback writes are disabled.
If Draft Mode delays companion read-back until commit, the push succeeds as a
tracked pending edit. The push does not immediately read the source back.
Treat `pending: true` as accepted, do not retry, and use `pending verify` only
after the draft is committed.

## MCP-dependent commands

| Command | Description |
|---|---|
| `tools` | List connected MCP tools |
| `state` | Read MCP Studio state |
| `call <name> [json]` | Call an MCP tool; supports `--json-file`/`--json-stdin` |
| `smart <name> [json]` | Context-aware call; supports file/stdin JSON |
| `execute <code>` | Execute Luau; supports `--file`/`--stdin` |
| `edit`, `batch`, `find-replace`, `search` | High-level MCP edit helpers |

These commands return a connection error when the legacy MCP bridge is not
connected. Companion commands and full sync remain available independently.

## Context and memory

| Command | Description |
|---|---|
| `context` | Show or set session context |
| `ai-context [--json] [--project <dir>]` | Print a Studio and GitHub AI briefing |
| `github-context [owner/repo] [--json] [--project <dir>]` | Read GitHub REST API context |
| `remember <text> [options]` | Pin durable project memory |
| `memory` | List pinned memory |
| `memory clear [id]` | Clear one or all entries |
| `pending` | List tracked pushes |
| `pending verify` | Verify tracked Studio sources |
| `pending clear [path]` | Clear tracked push records |

# Command and Transport Reference

## Transport matrix

| Operation | Companion | MCP required |
|---|---:|---:|
| Health and plugin status | Yes | No |
| Inspect children and selection | Yes | No |
| Full-place script pull | Yes | No |
| Update an existing pulled script | Yes | No |
| Verify current script source | Yes | No |
| Targeted pull | No | Yes |
| Create a new script | No | Yes |
| Generic MCP tool calls and Luau execution | No | Yes |

Roblox's current official MCP client uses `StudioMCP.exe` over stdio. Abraxius
still exposes its legacy inbound WebSocket compatibility route at
`ws://127.0.0.1:13469/studio`; do not assume that route is connected merely
because the companion is healthy.

## Ports

| Port | Service |
|---:|---|
| `13469` | Legacy MCP WebSocket compatibility listener |
| `13470` | Abraxius local HTTP API |
| `13471` | Studio companion long-poll channel |

## File mapping

| Local form | Studio class |
|---|---|
| `Name.server.luau` | `Script` |
| `Name.client.luau` | `LocalScript` |
| `Name.luau` | `ModuleScript` |
| `Name/init.server.luau` | `Script` with children |
| `Name/init.client.luau` | `LocalScript` with children |
| `Name/init.luau` | `ModuleScript` with children |

`place.json` maps each service to its local `$path`. Push rejects files outside
those mapped directories.

## Diagnostics

```powershell
# App and daemon health
Invoke-RestMethod http://127.0.0.1:13470/health

# Companion session
rust\abraxius-rs\target\release\abraxius.exe plugin status

# Live object inspection
rust\abraxius-rs\target\release\abraxius.exe plugin inspect Workspace

# Current source
node cli.js plugin call read_source '{"path":"game.ServerScriptService.KnitServer"}'

# Listening processes
Get-NetTCPConnection -LocalPort 13469,13470,13471
```

## Common failures

- **Daemon did not become ready**: use a current CLI where full pull uses daemon
  readiness rather than MCP readiness. Confirm `/health` reports `running`.
- **Studio plugin not connected**: install with `npm run install-plugin`, enable
  HTTP Requests in Studio, and restart Studio only after protecting unsaved work.
- **Creating new scripts still requires MCP**: create the instance in Studio or
  complete the modern `StudioMCP.exe` integration before pushing a new file.
- **Push output succeeded but Studio differs**: treat it as failure, restore the
  original source, and inspect Draft Mode or open script documents.

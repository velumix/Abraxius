# Command and Transport Reference

## Transport matrix

| Operation | Companion | MCP required |
|---|---:|---:|
| Health and plugin status | Yes | No |
| Inspect children and selection | Yes | No |
| Full-place script pull | Yes | No |
| Update an existing pulled script | Yes (initial read/pending tracking) | Yes (`multi_edit`) |
| Verify current script source | Yes | No |
| Targeted pull | No | Yes |
| Create a new script | Yes (pending tracking) | Yes (`multi_edit`) |
| Execute Luau in Edit mode | Yes | No |
| Generic MCP tool calls | No | Yes |

## Companion editing protocol

Companion `v1.3.0` adds assistant-oriented discovery and safe instance editing:

```powershell
node cli.js plugin call get_capabilities '{}'
node cli.js plugin call get_assistant_context '{}'
```

Roblox datatypes use explicit JSON values. For example, a Vector3 is encoded as
`{"$type":"Vector3","x":0,"y":5,"z":0}` and a Color3 can be encoded as
`{"$type":"Color3uint8","r":255,"g":128,"b":0}`. Supported types are
reported by `get_capabilities`.

Mutation commands are `set_properties`, `create_instance`, `clone_instance`,
`reparent_instance`, `transform_instance`, and `delete_instance`. Lifecycle and
transform commands require Studio edit mode. Deletion additionally requires
`confirm=true`, refuses data models and services, and creates undo waypoints.

Use `get_properties` after each edit. It returns the same typed JSON format, so
Vector3, CFrame, Color3, enum, UI, range, rectangle, and instance-reference
values can be compared without lossy string conversion.

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
| `13472` | Studio analytics probe and snapshot API |

## Analytics

Companion `v1.4.0` posts public Studio telemetry to the isolated analytics
listener. Read the current merged snapshot with:

```powershell
Invoke-RestMethod http://127.0.0.1:13472/snapshot
```

The snapshot includes total and developer-tag memory, edit/play role,
client/server identity, player count, physics frequency, probe latency, and
cached DataModel counts. Memory is sampled every two seconds; the more expensive
hierarchy count runs every ten seconds. The Windows app independently samples
Roblox Studio and Rust-host process working set and CPU usage.

Companion `v1.5.0` also retains the latest play session in `studio.playtest`.
The bounded payload contains up to 200 categorized output entries (`error`,
`warning`, `info`, or `print`), session duration and counts, and extracted
script/line hints when Studio includes them. `studio.scriptActivity` contains up
to 100 recent source changes with path, size, hash, timestamp, and play-mode
identity. Buffers reset when a new play session begins and remain available after
it stops.

The Windows app exposes this through Overview, Playtest, Output, and Scripts
navigation categories. Output filtering happens locally and does not add traffic
to the Studio command channel.

Companion `v1.5.1` adds a persistent **Play data analytics** toggle on its
Signals page. Disabling it immediately clears and stops detailed play output and
source-activity collection while leaving base health telemetry connected. The
same setting is available to automation through `get_play_data_settings` and
`set_play_data_enabled` companion commands.

Companion `v1.5.2` implements protocol version 3 with explicit `write_source`,
`create_script`, `rename_instance`, and confirmed `execute_luau` commands.
Source writes use `ScriptEditorService:UpdateSourceAsync` with a direct Studio
source fallback, optional optimistic hash checks, undo waypoints, and immediate
readback verification. Luau execution is restricted to Edit mode, requires
`confirm=true`, limits code to 64 KiB, runs inside a uniquely named temporary
ModuleScript, and destroys the runner on both success and failure.

Companion `v1.6.0` implements protocol version 4. `get_capabilities` now returns
a JSON-Schema-shaped `commands` map, plus a `canonicalization` map documenting
that `Color3uint8` inputs read back as normalized `Color3` values. `create_script`
accepts either `path` or `parent` + `name`. `write_source` accepts `dryRun=true`
and returns a line-oriented `diff` (`startLine`, `removed`, and `added`) without
changing Studio. The same diff is returned after a committed write.

The companion `batch` command accepts up to 50 mutation `operations`. It uses a
single Studio history recording and commits only when every operation succeeds;
on the first failure it cancels the recording, rolls back prior operations, and
returns `rolledBack=true` with `failedIndex`. Nested batches and non-mutation
commands are rejected.

## File mapping

| Local form | Studio class |
|---|---|
| `Name.server.luau` | `Script` |
| `Name.client.luau` | `LocalScript` |
| `Name.luau` | `ModuleScript` |
| `Name/init.server.luau` | `Script` with children |
| `Name/init.client.luau` | `LocalScript` with children |
| `Name/init.luau` | `ModuleScript` with children |
| `Name.rbxm` / `Name.rbxmx` | Imported instance tree (push only) |

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

For payloads containing source, quotes, backslashes, PowerShell metacharacters,
or Unicode, bypass command-line escaping:

```powershell
node cli.js plugin call write_source --json-file .\write-source.json
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Get-Content -Encoding UTF8 -Raw .\write-source.json | node cli.js plugin call write_source --json-stdin
node cli.js execute --file .\probe.luau
```

Prefer files for byte-exact Unicode under Windows PowerShell 5.1. For stdin,
both `$OutputEncoding` and `Get-Content -Encoding UTF8` are required. The Node
and Rust CLIs accept `--json-file`/`--json-stdin` for raw calls and
`--file`/`--stdin` for `execute`.

## Common failures

- **Port 13469 is owned by another process**: use the **Force MCP connection**
  button beside the MCP status. Abraxius names the listener and PID, requires
  confirmation before terminating it, refuses to terminate Abraxius or Roblox
  Studio, then restarts the Rust host and verifies port ownership.
- **Daemon did not become ready**: use a current CLI where full pull uses daemon
  readiness rather than MCP readiness. Confirm `/health` reports `running`.
- **Studio plugin not connected**: install with `npm run install-plugin`, enable
  HTTP Requests in Studio, and restart Studio only after protecting unsaved work.
- **Script push reports MCP unavailable**: reconnect MCP and confirm the
  companion is healthy. Whole-script companion fallback is intentionally
  disabled.
- **Push reports `pending: true`**: MCP accepted the change. Do not retry or
  immediately read it back. Wait for the user to commit the draft, then run
  `pending verify` only if the source-change event has not cleared the record.
- **Push exits nonzero or reports an error**: treat it as failure and diagnose
  the reported transport or edit problem. Do not substitute a whole-source
  write.

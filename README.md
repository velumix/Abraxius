# Abraxius

Built by **VELUMIX**.

Abraxius is a Windows-hosted Roblox Studio companion and verified Luau script
sync system. Its packaged WinUI 3 app keeps a Rust daemon active in the taskbar
and notification area while thin local CLIs ask the app-owned host to inspect
Studio, pull projects, push existing script edits, and build AI context.

Current tested release: **Abraxius App 1.14.5**, **Studio companion 1.8.1**,
and **companion protocol 6**.

## Components

- **Abraxius.App**: System-themed WinUI 3 supervisor with taskbar, tray,
  startup, restart, and full quit controls.
- **Rust daemon**: Local health and control API on `13470`, companion channel
  on `13471`, and legacy MCP listener on `13469`.
- **Studio companion**: Roblox-side authority for live inspection, selection,
  script export, source revisions, AXL parsing and execution, edits,
  ChangeHistory, and Draft Mode detection.
- **Node CLI**: Thin app-host client for high-level pull, push, context, memory,
  AXL, and optional MCP tools.
- **Rust CLI**: Thin native client for status, companion, pending-push, and
  context commands.
- **AI agent workflow**: Model-neutral operating rules in `AGENTS.md` and
  `docs/ai-usage.md`, with the reusable skill package in
  `skills/abraxius-studio-sync` and host-specific discovery adapters kept
  separate.

## Control model

```text
AI or CLI
    |
    v
Abraxius App-owned Rust host
    |
    v
Roblox Studio companion
    |
    v
Live Roblox DataModel
```

The app is the only host supervisor. The Node and Rust CLIs are thin clients:
they cannot start a competing daemon or stop the app-owned host. Start,
restart, stop, and quit are controlled from the Abraxius window or tray menu.

The Studio companion performs work that depends on live Roblox state. It
resolves instances, reads source, computes revisions, applies AXL patches with
`ScriptEditorService`, records ChangeHistory operations, and reports whether
Draft Mode accepted an edit as pending.

Tell any connected AI client or agent to **use Abraxius**. Skill-aware clients
can explicitly invoke `$abraxius-studio-sync`; other clients can read
`AGENTS.md` and `docs/ai-usage.md` or call the same CLI and local API directly.
For a normal script change, the agent edits the mapped local file and runs one
`node cli.js push <file>` command. Abraxius—not the model—calculates
`multi_edit` operations. Changed scripts are tracked as `pending` until Studio
commits them; agents must not retry or immediately read them back while Draft
Mode can hide the uncommitted source.

All AI integrations should read [docs/ai-usage.md](docs/ai-usage.md) first. It
is the canonical, model-neutral guide for choosing between the app, CLI,
companion commands, AXL, and MCP tools. The root [AGENTS.md](AGENTS.md)
contains the short non-negotiable rules, and
[skills/abraxius-studio-sync](skills/abraxius-studio-sync) packages the same
workflow for skill-aware agent hosts.

The npm CLI is exposed as `abraxius`. The older `mcp` executable remains as a
compatibility alias.

## Install

```powershell
npm install
npm run rust:build
npm run install-plugin
npm run app:run
```

Enable **Allow HTTP Requests** in Roblox Studio under **Game Settings >
Security**. Restart Studio after installing the companion only after protecting
unsaved work.

## Windows app

```powershell
npm run app:build
npm run app:run
```

The registered Abraxius app can be pinned to the taskbar. Closing the window
keeps the app and daemon running in the notification area. Use **Quit Abraxius**
from the tray menu to stop both processes.

The app follows Windows light, dark, and high-contrast themes. It uses the
project `Logo.png` for the application identity and `Tray.png` for the
notification icon.

## Verify Studio communication

```powershell
node cli.js status
node cli.js plugin status
node cli.js plugin inspect Workspace
node cli.js plugin call read_source '{"path":"game.ServerScriptService.KnitServer"}'
```

The companion can be connected while the legacy MCP status is waiting.

## AXL: compact AI commands

AXL is Abraxius's compact, typed AI command language. The CLI transports the
original text through the app-owned host; the Studio companion parses and
executes it.

```powershell
node cli.js axl 'hello axl/1'
node cli.js axl 'state'
node cli.js axl 'find "EndRound" budget=500'
node cli.js axl 'read ServerScriptService.KnitServer summary'
```

Example compact responses:

```text
READY axl/1 ns=0 tools=core,studio
SUM ServerScriptService.KnitServer@3337966330 lines=15 bytes=605 symbols=0
```

Revision-safe patches use an exact old/new heredoc:

```text
patch ServerScriptService.MatchManager@308937084
old <<OLD
local speed = 10
OLD
new <<NEW
local speed = 20
NEW
```

Use `node cli.js axl --file .\change.axl` or `--stdin` for multiline commands.
An accepted Draft Mode edit returns `pending=1`; do not retry or read it back
until the user commits the draft. See [docs/axl.md](docs/axl.md) for the full
AXL/1 grammar.

## Command Center

The app's **Commands** page discovers the live companion schema. Commands can
be reviewed, queued, saved as workflows, or drafted by the configured AI
provider. Mutations always require approval.

For an explicitly requested manual replacement, Command Center exposes compact
`multi_edit` JSON:

```json
{
  "file_path": "game.ServerScriptService.Main",
  "edits": [
    {
      "old_string": "local speed = 10",
      "new_string": "local speed = 20"
    }
  ]
}
```

The app injects `datamodel_type: "Edit"` and sends the command through MCP.
For normal mapped-file work, use `node cli.js push <file>` instead so Abraxius
generates the exact granular edits and tracks Draft Mode.

## Pull

Full pull uses the Studio companion bulk export and does not require MCP:

```powershell
node cli.js pull game
```

The output contains:

```text
game/
|-- place.json
`-- src/
    |-- ReplicatedStorage/
    |-- ServerScriptService/
    `-- Workspace/
```

Targeted pull remains MCP-dependent:

```powershell
node cli.js pull --target ServerScriptService.KnitServer game
```

## Push

Edit a file inside a pulled project and push it:

```powershell
node cli.js push game\src\ServerScriptService\KnitServer.server.luau
```

Script pushes require both MCP and the companion. Abraxius reads the committed
source and generates narrow atomic `multi_edit` operations. A changed push
returns `pending: true` as soon as MCP accepts it; Abraxius deliberately avoids
immediate source read-back because Draft Mode exposes only committed source and
can hang that check. Do not retry the push. Verify after committing the draft.
Abraxius never falls back to replacing a whole script. New scripts are created
through the `multi_edit` creation contract.

File conventions:

| Extension | Roblox class |
|---|---|
| `.server.luau` | `Script` |
| `.client.luau` | `LocalScript` |
| `.luau` | `ModuleScript` |
| `init.server.luau` | `Script` with children |
| `init.client.luau` | `LocalScript` with children |
| `init.luau` | `ModuleScript` with children |

## AI context and memory

```powershell
node cli.js remember "KnitServer owns service startup." --tag architecture `
  --path ServerScriptService.KnitServer
node cli.js memory
node cli.js ai-context
```

Pinned memory is stored in `.abraxius/memory.json`. Context briefings also
include companion state, recent Studio activity, scripts, operations, and
pending pushes.

## MCP compatibility

The `/studio` WebSocket listener implements the earlier Roblox Studio MCP
transport. Current Roblox releases use `StudioMCP.exe` over stdio. Generic MCP
tool calls, targeted pull, and every script push require a connected MCP
transport. Companion inspection and full pull work without MCP.

## Documentation

Start with the guide that matches the task:

- [AI usage](docs/ai-usage.md): canonical agent workflow and Command Center JSON
- [AI agent skill](docs/agent-skill.md): model-neutral skill discovery and guarantees
- [AXL](docs/axl.md): compact typed AI-to-Abraxius command language
- [Windows app](docs/windows-app.md): UI pages and lifecycle
- [CLI](docs/cli.md): command syntax
- [Sync](docs/sync.md): file mapping, push verification, and Draft Mode
- [API](docs/api.md): transports and local endpoints

Moonwave documentation lives under `docs/`.

```powershell
npm run docs:dev
npm run docs:build
```

The static site is generated into `build/`.

## Validation

```powershell
npm test
npm run plugin:build
npm run smoke
npm run rust:check
npm run app:build
npm run docs:build
```

The AXL write path was also tested live in Studio: create a disposable
ModuleScript, read its revision, apply an exact patch, receive `pending=1`,
commit the draft, verify the predicted revision and source, and delete the
artifact. The final companion queue was empty.

## License

MIT

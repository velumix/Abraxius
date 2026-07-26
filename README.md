# Abraxius

Built by **VELUMIX**.

Abraxius is a Windows-hosted Roblox Studio companion and verified Luau script
sync system. Its packaged WinUI 3 app keeps a Rust daemon active in the taskbar
and notification area while thin local CLIs ask the app-owned host to inspect
Studio, pull projects, push existing script edits, and build AI context.

## Components

- **Abraxius.App**: System-themed WinUI 3 supervisor with taskbar, tray,
  startup, restart, and full quit controls.
- **Rust daemon**: Local health and control API on `13470`, companion channel
  on `13471`, and legacy MCP listener on `13469`.
- **Studio companion**: Live inspection, selection, script export, source
  read-back, activity reporting, and existing-script updates.
- **Node CLI**: Thin app-host client for high-level pull, push, context, memory,
  AXL, and optional MCP tools.
- **Rust CLI**: Thin native client for status, companion, pending-push, and
  context commands.
- **Codex skill**: Repository-local guarded sync workflow at
  `.codex/skills/abraxius-studio-sync`.

Tell Codex to **use Abraxius** (or explicitly name
`$abraxius-studio-sync`). For a normal script change, Codex edits the mapped
local file and runs one `node cli.js push <file>` command. Abraxius—not the
agent—calculates `multi_edit` operations. Changed scripts are tracked as
`pending` until Studio commits them; agents must not retry or immediately read
them back while Draft Mode can hide the uncommitted source.

AI agents should read [docs/ai-usage.md](docs/ai-usage.md) first. It is the
canonical guide for choosing between the app, CLI, companion commands, and MCP
tools. The root [AGENTS.md](AGENTS.md) contains the short non-negotiable rules.

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
npm run smoke
npm run rust:check
npm run app:build
npm run docs:build
```

## License

MIT

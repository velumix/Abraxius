# Abraxius

Built by **VELUMIX**.

Abraxius is a Windows-hosted Roblox Studio companion and verified Luau script
sync system. Its packaged WinUI 3 app keeps a Rust daemon active in the taskbar
and notification area while local CLIs inspect Studio, pull projects, push
existing script edits, and build AI context.

## Components

- **Abraxius.App**: System-themed WinUI 3 supervisor with taskbar, tray,
  startup, restart, and full quit controls.
- **Rust daemon**: Local health and control API on `13470`, companion channel
  on `13471`, and legacy MCP listener on `13469`.
- **Studio companion**: Live inspection, selection, script export, source
  read-back, activity reporting, and existing-script updates.
- **Node CLI**: High-level pull, push, context, memory, and optional MCP tools.
- **Rust CLI**: Native status, companion, pending-push, and context commands.
- **Codex skill**: Repository-local guarded sync workflow at
  `.codex/skills/abraxius-studio-sync`.

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

With MCP offline, Abraxius updates an existing Studio script through the
companion and reads the source back before reporting success. Creating a new
script still requires MCP.

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
tool calls, targeted pull, and new-script creation require a compatible modern
transport integration. Companion inspection, full pull, and existing-script
push work independently.

## Documentation

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

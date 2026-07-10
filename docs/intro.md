# Introduction

Abraxius is a Windows-hosted Roblox Studio companion and script-sync system. A
packaged WinUI 3 app keeps the Rust daemon active, exposes a local HTTP API, and
supervises the Studio companion connection.

## What it does

- **Windows app**: Runs in the taskbar and notification area, follows the system
  theme, starts the Rust daemon, and can launch with Windows.
- **Studio companion**: Inspects instances, reads script sources, exports the
  open place, reports activity, and applies verified updates to existing scripts.
- **Script sync**: Maps Roblox services and scripts to `place.json` plus familiar
  `.luau`, `.server.luau`, and `.client.luau` files.
- **HTTP API and CLIs**: Expose daemon health, companion commands, AI context,
  memory, sync, and optional MCP calls to local tools.
- **Codex skill**: Provides a guarded pull, edit, push, and read-back workflow.

## Architecture

```text
Abraxius.App (WinUI 3)
        |
        +-- supervises --> abraxius-daemon.exe
                              |
node cli.js / abraxius.exe --HTTP--> 127.0.0.1:13470
                              |
                              +-- companion long-poll --> Studio plugin :13471
                              |
                              +-- legacy MCP listener --> ws://127.0.0.1:13469/studio
```

The companion path is the reliable path for full-place pull, live inspection,
source read-back, and updates to existing scripts. The legacy MCP listener
remains available, but current Roblox releases use `StudioMCP.exe` over stdio
and require a future transport integration for generic MCP tools.

## Quick start

```powershell
npm install
npm run rust:build
npm run install-plugin
npm run app:run

node cli.js plugin status
node cli.js pull game
node cli.js push game\src\ServerScriptService\KnitServer.server.luau
```

See [Windows App](windows-app.md), [Sync Workflow](sync.md), and
[Codex Skill](codex-skill.md) for the complete workflows.

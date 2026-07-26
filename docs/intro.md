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
- **Codex skill**: Provides a guarded pull, edit, push, and pending-tracking workflow.

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

The companion path handles full-place pull, live inspection, and committed
source reads. Script push combines an initial companion read with MCP
`multi_edit`; changed scripts are tracked as pending without immediate read-back
so Draft Mode cannot block the push. It requires both connections. The legacy
MCP listener remains for compatibility with earlier Studio transports.

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

AI agents should start with [AI Guide: Using Abraxius](ai-usage.md). Human-facing
details continue in [Windows App](windows-app.md), [Sync Workflow](sync.md), and
[CLI Reference](cli.md).

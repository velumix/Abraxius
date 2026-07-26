---
sidebar_position: 2
---

# Installation

## Requirements

| Requirement | Why it is needed |
| --- | --- |
| Windows 10 or Windows 11 | Abraxius.App is a packaged WinUI 3 application |
| Node.js 20 or newer | Runs the CLI, tests, plugin builder, and documentation tooling |
| Rust toolchain | Builds the native host and control CLI |
| .NET 11 Preview SDK | Builds the current WinUI application while .NET 11 is pre-release |
| Windows Developer Mode | Allows development package registration |
| Roblox Studio | Hosts the Abraxius companion |

Roblox Studio must allow local HTTP requests. You will enable that after the
companion is installed.

## Get the source

```powershell
git clone https://github.com/velumix/Abraxius.git
cd Abraxius
npm install
```

`npm install` provides the Node CLI, GitHub context provider, test suite, plugin
builder, and Moonwave documentation tooling.

## Build the native host

```powershell
npm run rust:build
```

The release binaries are written under `rust\abraxius-rs\target\release`.

## Install the Studio companion

```powershell
npm run install-plugin
```

This writes:

```text
%LOCALAPPDATA%\Roblox\Plugins\AbraxiusCompanion.lua
```

Protect unsaved work before restarting Studio. Open **Game Settings >
Security**, enable **Allow HTTP Requests**, and reopen the place you want
Abraxius to inspect.

## Build and run the Windows app

```powershell
npm run app:build
npm run app:run
```

`app:run` registers and launches the development package. Abraxius then appears
in Start and can be pinned to the taskbar. Closing its window leaves the app and
Rust server active in the notification area.

:::info App ownership
Abraxius.App owns the Rust host. Do not run a second daemon beside the app.
Start, restart, stop, and full quit belong to the app window or tray menu.
:::

## Verify the connection

```powershell
npm run smoke
node cli.js status
node cli.js plugin status
node cli.js plugin inspect Workspace
```

The app should report:

- **Server: Running**
- **Companion: Connected**
- the active place in Studio context

The legacy Studio MCP card may remain **Waiting** while companion inspection
and full pull continue to work. Script push still requires both the companion
and a compatible MCP transport.

Test a full export only after the health checks succeed:

```powershell
node cli.js pull game
```

## Optional global CLI

```powershell
npm install -g .
abraxius status
abraxius pull game
```

The older `mcp` executable remains as a compatibility alias.

## MCP compatibility

Current Roblox Studio releases expose their official MCP client through
`%LOCALAPPDATA%\Roblox\mcp.bat` and `StudioMCP.exe` using stdio. Abraxius's
legacy WebSocket route is not a replacement for that transport. Generic MCP
calls, targeted pull, and every script push require a compatible MCP connection.
Companion-based full pull remains available without MCP.

## Next steps

- Learn the desktop workspace in [Windows app](windows-app.md).
- Export and update scripts with [Sync workflow](sync.md).
- Connect a coding agent with [AI workflow](ai-usage.md).
- Diagnose local transports with [Local API reference](api.md).

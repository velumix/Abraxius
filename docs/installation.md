# Installation

## Requirements

- Windows 10 or Windows 11
- Node.js 18+
- Rust toolchain
- .NET 9 SDK
- Windows Developer Mode for development package registration
- Roblox Studio with **Allow HTTP Requests** enabled

## Install dependencies

```powershell
git clone https://github.com/velumix/Abraxius.git
cd Abraxius
npm install
npm run rust:build
```

## Install the Studio companion

```powershell
npm run install-plugin
```

This installs `%LOCALAPPDATA%\Roblox\Plugins\AbraxiusCompanion.lua`. Restart
Studio after protecting unsaved work. In Studio, open **Game Settings >
Security** and enable **Allow HTTP Requests**.

## Build and run the Windows app

```powershell
npm run app:build
npm run app:run
```

`app:run` registers and launches the development package. Abraxius then appears
in Start and can be pinned to the taskbar. Closing its window leaves the app and
Rust server active in the notification area.

## Verify

```powershell
npm run smoke
node cli.js plugin status
node cli.js plugin inspect Workspace
node cli.js pull game
```

The app should show **Server: Running** and **Companion: Connected**. The Studio
MCP card may remain **Waiting** while companion-based sync continues to work.

## Optional global CLI

```powershell
npm install -g .
mcp status
mcp pull game
```

## MCP compatibility

Current Roblox Studio releases expose their official MCP client through
`%LOCALAPPDATA%\Roblox\mcp.bat` and `StudioMCP.exe` using stdio. Abraxius's
legacy WebSocket route is not a replacement for that transport. Generic MCP
calls, targeted pull, and new-script creation require a compatible MCP
connection; companion-based full pull and existing-script push do not.

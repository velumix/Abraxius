# Rust Host and WinUI App

Abraxius includes two Rust binaries and a packaged WinUI 3 frontend:

- `abraxius.exe`: native control CLI
- `abraxius-daemon.exe`: local API and companion host
- `Abraxius.App.exe`: Windows supervisor

## Build

```powershell
npm run rust:check
npm run rust:build
npm run app:build
```

The Rust release binaries are written under
`rust/abraxius-rs/target/release/`. The app build embeds the daemon in its
packaged output.

## Run

```powershell
npm run app:run
```

For CLI-only control:

```powershell
npm run rust:run -- status
npm run rust:run -- plugin status
npm run rust:run -- plugin inspect Workspace
npm run rust:run -- ai-context
```

## Ports

| Port | Purpose |
|---:|---|
| `13469` | Legacy MCP WebSocket listener at `/studio` |
| `13470` | Main local HTTP API |
| `13471` | Studio companion long-poll channel |

## Windows lifecycle

The WinUI app:

- starts and supervises the embedded Rust daemon
- displays server, MCP, and companion states independently
- hides to the notification area when its window closes
- restores the existing process on repeated Start/taskbar activation
- supports server restart without duplicating supervisors
- optionally launches through a packaged Windows startup task
- stops both the daemon and app through **Quit Abraxius**

The app follows the Windows system theme using WinUI theme resources and Mica.

## Rust CLI commands

| Command | Description |
|---|---|
| `status` | Read daemon health |
| `start` | Start the native daemon in the background |
| `start-node` | Start the legacy Node daemon |
| `stop` | Shut down the active daemon |
| `tools`, `state`, `call`, `execute` | Use connected MCP tools |
| `plugin ...` | Inspect or command the companion |
| `pending ...` | Read or verify tracked pushes |
| `ai-context` | Build an AI briefing |
| `remember`, `memory` | Manage durable project memory |
| `install-plugin` | Install the companion plugin |

The Node CLI remains the high-level interface for project pull and push. It
uses the API hosted by the app's Rust daemon.

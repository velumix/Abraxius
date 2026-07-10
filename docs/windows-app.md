# Windows App

Abraxius.App is a packaged WinUI 3 supervisor for the Rust daemon. It follows
the Windows light, dark, and high-contrast themes and uses the project `Logo`
and `Tray` assets for its app and notification-area identities.

## Build and launch

```powershell
npm run app:build
npm run app:run
```

`app:run` registers and launches the development package. The registered
Abraxius entry then appears in Start and can be pinned to the taskbar.

## Lifecycle

- Launch starts and monitors `abraxius-daemon.exe`.
- Closing the window hides it while the app and daemon remain active.
- Reopening from Start or the taskbar restores the existing single instance.
- **Restart server** replaces the daemon without duplicating the app.
- **Quit Abraxius** stops the daemon and exits the app.
- **Start with Windows** registers the packaged startup task.
- **Keep the Rust server running** controls automatic supervision.

## Status cards

The window reports three independent states:

- **Server**: Rust daemon health on port `13470`
- **Roblox Studio**: legacy MCP connection state
- **Companion**: Studio plugin session on port `13471`

Companion-based pull and existing-script push can work while the MCP card says
**Waiting**.

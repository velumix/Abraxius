---
sidebar_label: Troubleshooting
---

# App troubleshooting

Start with the three read-only checks:

```powershell
node cli.js status
node cli.js plugin status
node cli.js plugin events 20
```

## Connection problems

| Symptom | Check | Action |
|---|---|---|
| Server is stopped | Home server card | Start the app-owned host |
| Companion is disconnected | HTTP Requests and plugin installation | Enable HTTP Requests, reinstall the plugin, then protect work before restarting Studio |
| MCP is waiting | Studio MCP transport and port `13469` | Reconnect MCP; do not substitute a whole-source write |
| Full pull works but push fails | MCP state | Full pull needs only the companion; push needs companion and MCP |

## Command discovery

If Commands reports unavailable:

1. Confirm the companion card is connected.
2. Run `node cli.js plugin status`.
3. Select **Discover** again.
4. Check the app version.

Abraxius App 1.15.1 separates one-second health polling from the 35-second
Studio command timeout. Earlier builds may cancel a healthy discovery request
after one second.

## The development app does not launch

Use the package-aware command:

```powershell
npm run app:run
```

Do not launch the unpackaged `.exe` directly. Windows App SDK activation can
fail with `REGDB_E_CLASSNOTREG` when the development package has not been
registered.

## Code editor problems

| Symptom | Action |
|---|---|
| Script will not open | Verify the companion, then refresh the Studio script explorer |
| Preview reports a hash conflict | Pull the latest source and reapply the intended local edit |
| StyLua unavailable | Add `stylua.exe` to `PATH` and restart the app |
| Luau diagnostics unavailable | Add `luau-analyze.exe` to `PATH` and restart the app |
| Dirty buffers after restart | Review the locally recovered tabs before applying |

## Pending Draft Mode changes

`pending: true` from a mapped CLI push means MCP accepted the edit. Do not retry
or immediately read it back. Commit the draft in Studio, then use:

```powershell
node cli.js pending
node cli.js pending verify
```

only if the companion source-change event has not already cleared it.

## Support bundles

Create a bundle from Diagnostics or Settings. Bundles are stored under:

```text
%LOCALAPPDATA%\Abraxius\diagnostics
```

The app keeps the 10 newest archives. Bundles redact common token patterns and
exclude source code, editor buffers, AI conversations, project memory, and
command history.

## Logs and local state

The app data directory is:

```text
%LOCALAPPDATA%\Abraxius
```

Use the Home or Settings shortcut instead of deleting files manually. If you
need to report a problem, include the support bundle and the exact app and
companion versions.

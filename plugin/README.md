# Abraxius Studio Companion Plugin

This plugin lives in Roblox Studio and talks to the Abraxius daemon on a second HTTP port (`13471`). It gives Abraxius real-time visibility into Studio state, which makes Draft Mode pushes far less mysterious.

## What it does

- Reports `Source` changes as they happen in Studio.
- Reports selection changes and current play/edit mode.
- Responds to commands from Abraxius such as `read_source`, `get_selection`, and `get_state`.
- Lets Abraxius verify whether a pushed file has actually landed in the datamodel (or is still sitting as an uncommitted draft).
- Supports event subscriptions and reports recent events through `mcp plugin events`.
- Adds an Abraxius dock widget in Studio with connection status, session id, watched script count, queued events, and recent Studio events.

## Install

### Windows

Copy the plugin script into your Roblox Studio local plugins folder:

```powershell
Copy-Item "C:\Users\TheRe\Desktop\Abraxius\plugin\AbraxiusCompanion\init.server.luau" "$env:LOCALAPPDATA\Roblox\Plugins\AbraxiusCompanion.lua" -Force
```

Or from this directory run:

```bash
npm run install-plugin
```

### macOS

```bash
mkdir -p ~/Documents/Roblox/Plugins
cp plugin/AbraxiusCompanion/init.server.luau ~/Documents/Roblox/Plugins/AbraxiusCompanion.lua
```

Then restart Roblox Studio. You should see an **Abraxius** toolbar with a **Companion** button.

The plugin is intentionally installed as one `.lua` file. Do not install it as an `AbraxiusCompanion/init.server.luau` folder tree, because `init` files have Rojo-style folder semantics.

## Requirements

- Roblox Studio must have **HTTP Requests** enabled (`Game Settings > Security > Allow HTTP Requests`).
- The Abraxius daemon must be running (`mcp start`).

## Useful commands

```bash
mcp plugin
mcp plugin events 20
mcp plugin selection
mcp plugin state
mcp plugin call get_watched_sources
mcp plugin call resolve_path '{"path":"ServerScriptService.MatchManager"}'
```

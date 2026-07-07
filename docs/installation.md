# Installation

## Clone and install

```bash
git clone https://github.com/velumix/Abraxius.git
cd Abraxius
npm install
```

## Global install (optional)

To use the `mcp` command from anywhere:

```bash
npm install -g .
mcp status
mcp pull ./my-game
```

## Requirements

- Node.js 18+
- Roblox Studio open with MCP enabled in Assistant Settings
- No other MCP bridge running on `ws://localhost:13469/studio`

## Enable MCP in Roblox Studio

1. Open Roblox Studio.
2. Go to **File > Studio Settings > Assistant**.
3. Enable **MCP (Model Context Protocol)**.
4. Restart Studio if prompted.

Once enabled, Studio will attempt to connect to `ws://localhost:13469/studio` whenever a place is open.

## (Optional but recommended) Install the Studio Companion Plugin

The companion plugin gives Abraxius real-time visibility into Studio state and makes Draft Mode pushes trackable.

```bash
npm run install-plugin
```

This installs one local plugin script:

```text
Roblox/Plugins/AbraxiusCompanion.lua
```

Then restart Roblox Studio. You should see an **Abraxius** toolbar with a **Companion** button.

Do not install the source folder as `AbraxiusCompanion/init.server.luau`; `init` files have Rojo-style folder semantics, and the local Studio plugin should be a single script file.

The plugin needs **HTTP Requests** enabled:

1. Open **Game Settings**.
2. Go to **Security**.
3. Enable **Allow HTTP Requests**.

The plugin connects to `http://localhost:13471`.

## Verify the installation

```bash
npm run smoke
mcp status
mcp ai-context
```

`mcp ai-context` works even when the daemon is not connected to Studio, because pinned memory is stored locally in `.abraxius/memory.json`.

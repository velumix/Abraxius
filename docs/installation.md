# Installation

## Clone and install

```bash
git clone https://github.com/your-username/abraxius.git
cd abraxius
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

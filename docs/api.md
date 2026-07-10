# API Reference

Abraxius exposes a local HTTP API, the Studio companion channel, sync helpers,
and a legacy MCP compatibility listener.

## Ports

| Port | Purpose |
|---:|---|
| `13469` | Legacy MCP WebSocket listener at `/studio` |
| `13470` | Main local HTTP API |
| `13471` | Studio companion long-poll channel |

## HTTP client

`client.js` exports `MCPClient`, used by the Node CLI and sync helpers.

```js
const { MCPClient } = require("./client");
const client = new MCPClient();

await client.health();
await client.pluginStatus();
await client.pluginCall({ type: "get_children", path: "Workspace" });
await client.aiContext({ format: "markdown" });
```

## Core endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Daemon, MCP, and companion status |
| `GET` | `/tools` | Connected MCP tools |
| `POST` | `/call` | Call an MCP tool |
| `GET` | `/state` | Connected MCP Studio state |
| `POST` | `/execute` | Execute Luau through MCP |
| `GET` | `/ai-context` | AI context snapshot |
| `GET` | `/ai-context?format=markdown` | Markdown AI briefing |
| `GET` | `/memory` | Pinned project memory |
| `POST` | `/memory` | Add pinned memory |
| `POST` | `/memory/clear` | Clear memory |
| `POST` | `/shutdown` | Stop the daemon |

MCP endpoints return `503` when the MCP transport is disconnected. Health,
memory, and companion endpoints remain available.

## Companion endpoints

| Method | Path | Description |
|---|---|---|
| `POST` | `/plugin/register` | Register a Studio plugin session |
| `POST` | `/plugin/report` | Report events and receive queued commands |
| `GET` | `/plugin/status` | Read companion status |
| `GET` | `/plugin/events` | Read recent Studio events |
| `POST` | `/plugin/call` | Send one command to the plugin |

The request body for `/plugin/call` is:

```json
{
  "command": {
    "type": "get_children",
    "path": "Workspace"
  }
}
```

## Companion commands

| Type | Purpose |
|---|---|
| `read_source` | Read `LuaSourceContainer.Source` |
| `export_scripts` | Export script paths, classes, sources, and metadata |
| `get_children` | List direct children |
| `get_selection` / `set_selection` | Read or change Explorer selection |
| `open_script` | Open a script at a line |
| `get_state` | Read edit/play state |
| `resolve_path` | Resolve a Studio path |
| `get_properties` / `set_properties` | Read or set supported properties |
| `get_context_snapshot` | Read companion-observed context |
| `ping` | Verify the session |

## Puller

`lib/pull.js` first requests `export_scripts` from the companion. A full export
therefore works without MCP.

```js
const { Puller } = require("./lib/pull");
const puller = new Puller(client, { outputDir: "./game" });
const { project, stats } = await puller.pull();
```

Targeted pulls use MCP discovery and `script_read`.

## Pusher

`lib/push.js` resolves a file through `place.json`. With MCP connected it uses
MCP editing tools. Otherwise it updates an existing script through the
companion's property command and verifies the result with `read_source`.

```js
const { Pusher } = require("./lib/push");
const pusher = new Pusher(client, { projectDir: "./game" });
const result = await pusher.push(
  "./game/src/ServerScriptService/KnitServer.server.luau",
);
```

Companion fallback does not create missing script instances.

## Legacy MCP bridge

`bridge.js` and the Rust daemon expose `/studio` for the earlier Studio
WebSocket transport. Current Roblox releases use `StudioMCP.exe` over stdio;
do not use `health.connected` as a prerequisite for companion operations.

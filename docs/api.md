# API Reference

Abraxius exposes three main layers: the WebSocket bridge, the HTTP client, and the sync helpers.

## Ports

| Port | Purpose |
|---|---|
| `13469` | MCP WebSocket bridge (`/studio`) — Roblox Studio connects here |
| `13470` | Main HTTP API for the CLI and programmatic clients |
| `13471` | Studio Companion Plugin channel (HTTP long-poll) |

## `RobloxMCPBridge`

Defined in `bridge.js`. Handles the MCP client handshake over WebSocket.

### Constructor

```js
const { RobloxMCPBridge } = require("./bridge");
const bridge = new RobloxMCPBridge({
  port: 13469,
  path: "/studio",
  clientInfo: { name: "roblox-mcp-bridge", version: "1.0.0" },
  protocolVersion: "2024-11-05",
});
```

### Methods

| Method | Description |
|---|---|
| `start(timeoutMs)` | Start WebSocket server and wait for Studio |
| `stop()` | Close the bridge |
| `listTools()` | List available MCP tools |
| `callTool(name, args)` | Call an MCP tool |
| `getStudioState()` | Get current Studio state |
| `executeLuau(code, datamodelType)` | Execute Luau in Studio |
| `logToStudio(message)` | Print a message to Studio output |

### Events

- `listening`
- `connection`
- `ready`
- `disconnect`
- `error`

## `MCPClient`

Defined in `client.js`. Talks to the local HTTP API served by `server.js`.

```js
const { MCPClient } = require("./client");
const client = new MCPClient();

await client.health();
await client.tools();
await client.state();
await client.call("execute_luau", { code: 'print("hi")', datamodel_type: "Edit" });
await client.execute("print('hi')");
await client.pending();
await client.pendingVerify();
await client.pluginStatus();
await client.pluginEvents({ limit: 20 });
await client.pluginCall({ type: "get_selection" });
await client.remember("MatchManager owns round flow.", {
  tags: ["architecture"],
  path: "ServerScriptService.MatchManager",
});
await client.aiContext({ format: "markdown" });
await client.shutdown();
```

## AI context and memory

Abraxius stores durable project memory in `.abraxius/memory.json` under the active project directory. This is intentionally explicit: pinned memory is treated as long-lived project context, while recent operations and plugin events are short-lived session context.

### HTTP endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/ai-context` | Full AI context snapshot as JSON |
| `GET` | `/ai-context?format=markdown` | Full AI context snapshot as Markdown |
| `GET` | `/memory` | Read pinned memory |
| `POST` | `/memory` | Add pinned memory with `text`, optional `tags`, `path`, and `projectDir` |
| `POST` | `/memory/clear` | Clear all memory, or one entry with `id` |

## `PluginServer`

Defined in `lib/plugin-server.js`. Serves the Studio companion plugin on port `13471`.

```js
const { PluginServer } = require("./lib/plugin-server");
const pluginServer = new PluginServer({ port: 13471 });
await pluginServer.start();

pluginServer.on("connect", (session) => console.log("plugin connected", session.id));
pluginServer.on("event", (ev) => console.log("plugin event", ev));

const result = await pluginServer.callPlugin({ type: "read_source", path: "ServerScriptService.MatchManager" });
const events = pluginServer.listEvents({ limit: 20 });
```

### Plugin endpoints

| Method | Path | Description |
|---|---|---|
| `POST` | `/plugin/register` | Plugin says hello and gets a session id |
| `POST` | `/plugin/report` | Plugin sends events/heartbeats and receives commands |
| `GET` | `/plugin/status` | Connection status |
| `GET` | `/plugin/events` | Recent companion events, with `limit` and `since` query params |
| `POST` | `/plugin/call` | Bridge a one-off command to the plugin |

### Commands the plugin handles

- `read_source` — returns `Script.Source` for a given Studio path
- `get_selection` — returns the current Explorer selection
- `get_state` — returns edit/play mode state
- `resolve_path` — resolves a Studio path to instance info
- `subscribe` — subscribes to event types
- `ping` — returns plugin heartbeat details
- `get_watched_sources` — returns watched script paths

## `PendingPushes`

Defined in `lib/pending.js`. Tracks pushes that are waiting for Studio commit.

```js
const { PendingPushes } = require("./lib/pending");
const pending = new PendingPushes();

pending.recordPush("game.ServerScriptService.MatchManager", source);
pending.verify("game.ServerScriptService.MatchManager", currentSource);
pending.list();
pending.clear("game.ServerScriptService.MatchManager");
```

### HTTP endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/pending` | List recorded pushes |
| `POST` | `/pending/verify` | Verify pending pushes against the live datamodel via the plugin |
| `POST` | `/pending/clear` | Clear one or all pending records |

## `Puller`

Defined in `lib/pull.js`. Pulls scripts from Studio into a local project.

```js
const { Puller } = require("./lib/pull");
const puller = new Puller(client, { outputDir: "./game" });
const { project, stats } = await puller.pull();
```

## `Pusher`

Defined in `lib/push.js`. Pushes a local script file back to Studio using `multi_edit`.

```js
const { Pusher } = require("./lib/push");
const pusher = new Pusher(client, { projectDir: "./game" });
const { changed, studioPath, result } = await pusher.push("./game/src/...");
```

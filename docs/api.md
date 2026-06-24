# API Reference

Abraxius exposes three main layers: the WebSocket bridge, the HTTP client, and the sync helpers.

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
await client.shutdown();
```

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

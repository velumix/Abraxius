# Sync Workflow

Abraxius can extract scripts from Studio into a local project and push your edits back. The layout uses standard Roblox Luau file extensions so scripts map cleanly between your filesystem and the Studio datamodel.

## Pull

`mcp pull <dir>` extracts scripts from the connected Studio instance.

```bash
mcp pull game
```

A typical pulled project looks like this:

```
my-game/
├── place.json
└── src/
    ├── ReplicatedStorage/
    │   ├── Config.luau
    │   └── Modules/
    │       └── SomeModule.luau
    ├── ServerScriptService/
    │   ├── MatchManager.server.luau
    │   └── CoinManager.luau
    ├── StarterGui/
    │   └── TrollUI/
    │       └── TrollUIClient.client.luau
    ├── StarterPlayer/
    │   └── StarterPlayerScripts/
    │       └── KnifeClient/
    │           ├── init.client.luau
    │           └── Child.luau
    └── Workspace/
        └── LobbyInteractives/
            └── DoubleVotePad.server.luau
```

## File extension conventions

| Extension | Roblox class |
|---|---|
| `.server.luau` | `Script` |
| `.client.luau` | `LocalScript` |
| `.luau` | `ModuleScript` |
| `init.server.luau` | `Script` with children |
| `init.client.luau` | `LocalScript` with children |
| `init.luau` | `ModuleScript` with children |

## place.json

`place.json` maps the local tree back to Roblox services:

```json
{
  "name": "my-game",
  "format": "abraxius-v1",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": { "$path": "src/ReplicatedStorage" },
    "ServerScriptService": { "$path": "src/ServerScriptService" }
  }
}
```

## Push

After editing a pulled script locally, push it back to Studio:

```bash
mcp push game/src/ServerScriptService/MatchManager.server.luau
```

This resolves the local file back to `game.ServerScriptService.MatchManager`, reads the current Studio source, and applies a `multi_edit` with your changes. If the file has not changed, nothing is sent.

## Programmatic sync

```js
const { MCPClient } = require("abraxius");
const { Puller } = require("abraxius/lib/pull");

const client = new MCPClient();
const puller = new Puller(client, {
  outputDir: "./pulled-place",
  onProgress: (action, target) => console.log(`[${action}] ${target}`),
});

const { project, stats } = await puller.pull();
console.log(project.name, stats);
```

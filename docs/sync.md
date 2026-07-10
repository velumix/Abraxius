# Sync Workflow

Abraxius can extract scripts from Studio into a local project and push local edits back. The layout uses standard Roblox Luau file extensions so scripts map cleanly between your filesystem and the Studio DataModel.

## Pull

`mcp pull <dir>` asks the Studio companion for one bulk script export, including
source and `RunContext` metadata. If the companion is unavailable or outdated,
it falls back to the parallel MCP crawler.

```bash
# Pull everything
mcp pull game

# Pull one script
mcp pull --target ServerScriptService.MatchManager game

# Pull a list of targets from a file, one Studio path per line
mcp pull --targets-file targets.txt game
```

A typical pulled project looks like this:

```text
my-game/
|-- place.json
`-- src/
    |-- ReplicatedStorage/
    |   |-- Config.luau
    |   `-- Modules/
    |       `-- SomeModule.luau
    |-- ServerScriptService/
    |   |-- MatchManager.server.luau
    |   `-- CoinManager.luau
    |-- StarterGui/
    |   `-- TrollUI/
    |       `-- TrollUIClient.client.luau
    |-- StarterPlayer/
    |   `-- StarterPlayerScripts/
    |       `-- KnifeClient/
    |           |-- init.client.luau
    |           `-- Child.luau
    `-- Workspace/
        `-- LobbyInteractives/
            `-- DoubleVotePad.server.luau
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

When the MCP transport is offline, Abraxius updates existing pulled scripts
through the connected Studio companion and verifies the resulting source.
Creating a brand-new script still requires the MCP transport.

This resolves the local file back to `game.ServerScriptService.MatchManager`.
With MCP connected, the pusher uses MCP edit tools. Otherwise it reads and
updates the existing script through the companion, then reads it back and
requires an exact source match before reporting success.

## Draft Mode verification

MCP pushes may be tracked as pending when Roblox Studio uses Draft Mode. Direct
companion fallback pushes are verified immediately through `read_source`.

```bash
# Push changes
mcp push game/src/ServerScriptService/MatchManager.server.luau

# See pushes waiting for commit
mcp pending

# Ask the companion plugin which pushes are live or stale
mcp pending verify

# Clear the tracker after you commit drafts in Studio
mcp pending clear
```

Statuses:

| Status | Meaning |
|---|---|
| `pending` | Pushed but not verified yet |
| `live` | Studio source matches the pushed source |
| `stale` | Studio source differs from the pushed source |
| `error` | Plugin disconnected or command failed |

## AI context tie-in

Pending pushes are included in `mcp ai-context`, so an AI agent can avoid assuming an edit is live in Studio before verification.

```bash
mcp ai-context
```

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

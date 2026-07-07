# Sync Workflow

Abraxius can extract scripts from Studio into a local project and push local edits back. The layout uses standard Roblox Luau file extensions so scripts map cleanly between your filesystem and the Studio DataModel.

## Pull

`mcp pull <dir>` extracts scripts from the connected Studio instance. Discovery and reads run in parallel with a small rate limit so large places finish quickly without hammering Studio.

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

This resolves the local file back to `game.ServerScriptService.MatchManager`, reads the current Studio source, and applies a `multi_edit` with your changes. If the file has not changed, nothing is sent.

## Draft Mode verification

When Roblox Studio is in Draft Mode, `mcp push` writes the script source but the change may not be visible in the live DataModel until you commit the draft in Studio. Abraxius tracks these pushes and verifies them through the companion plugin.

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

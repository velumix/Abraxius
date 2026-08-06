---
sidebar_position: 4
sidebar_label: Sync workflow
---

# Sync Workflow

Abraxius can extract scripts from Studio into a local project and push local
edits back. The layout uses standard Roblox Luau file extensions so scripts map
cleanly between the filesystem and Studio. AI agents should read [AI Guide:
Using Abraxius](ai-usage.md) first; this page contains detailed mapping and
Draft Mode behavior.

The normal loop is short:

```text
Pull from Studio -> edit local Luau -> push one file -> commit in Studio -> verify
```

```bash
node cli.js pull game
node cli.js push game/src/ServerScriptService/MatchManager.server.luau
node cli.js pending verify
```

:::important
A successful script push can be `pending` while Roblox Studio Draft Mode holds
the edit. Do not retry it. Commit the draft in Studio, then verify it.
:::

## Pull

`node cli.js pull <dir>` asks the Studio companion for one bulk script export, including
source and `RunContext` metadata. If the companion is unavailable or outdated,
it falls back to the parallel MCP crawler.

```bash
# Pull everything
node cli.js pull game

# Pull one script
node cli.js pull --target ServerScriptService.MatchManager game

# Pull a list of targets from a file, one Studio path per line
node cli.js pull --targets-file targets.txt game
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
| `.rbxm` / `.rbxmx` | Imported instance tree (push only) |

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
node cli.js push game/src/ServerScriptService/MatchManager.server.luau
node cli.js push game/src/Workspace/MainModule.rbxm
```

Script pushes require both the MCP transport and the connected Studio
companion. Abraxius refuses the push when either is unavailable instead of
falling back to a whole-script source replacement. When Draft Mode keeps the
companion read-back on the committed source, a successful MCP edit is reported
as `pending` and the exact intended local source is tracked until commit.

This resolves the local file back to `game.ServerScriptService.MatchManager`.
The pusher reads the exact committed Studio source through the companion,
builds narrow atomic edits, and applies them through MCP `multi_edit`. Changed
scripts are recorded as pending without an immediate source read-back because
Draft Mode does not expose uncommitted source to the companion. New scripts use
the `multi_edit` creation contract.

Model pushes use the Studio companion's `SerializationService` integration. The
asset must be inside a service mapped by `place.json`, is limited to 20 MiB,
requires Edit mode, creates Studio undo waypoints, and replaces only the instance
whose name matches the asset filename. Abraxius resolves the imported path after
commit before reporting success.

## Draft Mode verification

MCP pushes are tracked as pending after Studio accepts the edit. Abraxius does
not immediately read the source back because Draft Mode exposes only the last
committed source and that verification can hang. Verify after committing the
draft, either explicitly or through the companion's source-change event.

```bash
# Push changes
node cli.js push game/src/ServerScriptService/MatchManager.server.luau

# See pushes waiting for commit
node cli.js pending

# Ask the companion plugin which pushes are live or stale
node cli.js pending verify

# Clear the tracker after you commit drafts in Studio
node cli.js pending clear
```

If the Studio companion or host app is disconnected during `pending verify`, Abraxius returns an actionable diagnostic (`reason: "companion_disconnected"` or `"host_disconnected"`) without corrupting pending push records to an error state.

Statuses:

| Status | Meaning |
|---|---|
| `pending` | MCP accepted the edit and Abraxius recorded the intended source, but commit is not verified yet |
| `live` | Studio source matches the pushed source |
| `error` | Verification query failed due to invalid path or script error |

## AI context tie-in

Pending pushes are included in `node cli.js ai-context`, so an AI agent can
avoid assuming an edit is live in Studio before verification.

```bash
node cli.js ai-context
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

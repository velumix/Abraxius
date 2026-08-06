---
sidebar_position: 5
sidebar_label: AI workflow
---

# AI Guide: Using Abraxius

This is the canonical operating guide for an AI working in the Abraxius
repository. Start here; use the linked references only when more detail is
needed.

## Choose the right path

| Goal | Use |
|---|---|
| Connect generic MCP CLI agent | `node cli.js stdio` (or `.mcp.json`) |
| Discover agent capabilities | `node cli.js discovery` |
| Change a mapped Luau script | Edit locally, then `node cli.js push <file>` |
| Pull the open place | `node cli.js pull <directory>` |
| Inspect Studio | `node cli.js plugin inspect <path>` or `plugin call read_source` |
| Run a manual app command | **Commands** page in Abraxius.App |
| Apply exact manual replacements | Command Center `multi_edit` |
| Read session context | `node cli.js ai-context` |
| Read GitHub repository context | `node cli.js github-context` |
| Send compact AI commands | `node cli.js axl <command>`; the Studio plugin executes them |
| Diagnose connections | `node cli.js status` and `node cli.js plugin status` |

For normal source changes, always prefer the high-level `push` workflow over a
raw command. It uses less model context, generates narrow edits, creates missing
scripts when necessary, and tracks changed scripts until their drafts are
committed.

## Preflight

Run commands from the repository root:

```powershell
node cli.js status
node cli.js plugin status
```

Required state depends on the operation:

| Operation | Companion | MCP |
|---|---:|---:|
| Inspect, read source, or full pull | Required | Not required |
| Targeted pull | Not required | Required |
| Push a script | Required | Required |
| Command Center `multi_edit` | Required for discovery | Required to execute |

Abraxius.App supervises the Rust daemon and owns ports `13469` through `13471`.
The CLI is only a client of that app-owned host; it must never start a second
Node daemon or stop the host.

## Golden path for a script change

1. Confirm the target:

   ```powershell
   node cli.js plugin inspect ServerScriptService
   node cli.js plugin call read_source '{"path":"game.ServerScriptService.KnitServer"}'
   ```

2. If there is no mapped project yet, pull into a dedicated directory:

   ```powershell
   node cli.js pull game
   ```

3. Edit the mapped local `.luau` file with normal file-editing tools.

4. Push that exact file once:

   ```powershell
   node cli.js push game\src\ServerScriptService\KnitServer.server.luau
   ```

5. Trust the push result. An unchanged or immediately verifiable operation may
   report `verified: true`. A changed script normally reports `pending: true`
   after MCP accepts it. That is a successful tracked push, not a reason to
   retry.
6. If Studio uses Draft Mode, let the user commit the draft. Only after commit,
   use `node cli.js pending verify` if the companion's source-change event has
   not already verified it.

Do not manually calculate diffs, construct `multi_edit`, perform a whole-source
write, retry a pending push, or immediately read back a pending source. Draft
Mode exposes the last committed source, not the uncommitted edit.

### Interpret push results

| Result | Meaning | Next action |
|---|---|---|
| `verified: true` | No source change is waiting, or the operation was immediately verifiable | Finish |
| `pending: true` | MCP accepted the changed script and Abraxius recorded its intended source | Do not retry; wait for Draft Mode commit |
| Error or nonzero exit | The push was not accepted | Diagnose the reported failure |

## Command Center

Open Abraxius.App and select **Commands**:

1. Select **Discover** to refresh the live command catalog.
2. Choose a command and fill either the structured fields or the JSON editor.
3. Use **Run command** for one operation, or **Add to queue** for review and
   approval as a workflow.
4. Review every mutation confirmation. AI-drafted plans are queued and never
   execute without approval.

Companion commands are sent through `plugin/call`. `multi_edit` is an app-added
MCP command and is sent through `/call` automatically.

`axl` is a companion command: the app and CLI send one compact source string,
while the Studio plugin performs live search, reads, revision checks, edits,
execution, and state inspection. See [AXL](axl.md).

An AXL patch may return `pending=1` when Studio Draft Mode accepts the edit but
still exposes the previous committed source. Treat that as accepted: do not
retry or immediately read it. Read or verify only after the user commits the
draft.

### Compact `multi_edit` JSON

The app intentionally omits `datamodel_type` from the schema and injects
`"Edit"` during execution. An existing-script edit needs only:

```json
{
  "file_path": "game.ServerScriptService.Main",
  "edits": [
    {
      "old_string": "local speed = 10",
      "new_string": "local speed = 20"
    }
  ]
}
```

Edits run in array order and are atomic. `old_string` must match exactly. Add
`"replace_all": true` only when every match should change.

To create a script, also provide `className` (`Script`, `LocalScript`, or
`ModuleScript`) and use an empty `old_string` in the first edit:

```json
{
  "file_path": "game.ServerScriptService.NewScript",
  "className": "Script",
  "edits": [
    {
      "old_string": "",
      "new_string": "print(\"ready\")"
    }
  ]
}
```

Use this raw command only when the user deliberately wants a manual exact edit.
For changes made in a pulled project, use `push` so Abraxius owns edit
generation and pending tracking.

## Paths and mapped files

Studio paths use dots and may start with `game.`, for example
`game.ReplicatedStorage.Modules.Inventory`.

| Local filename | Studio class |
|---|---|
| `Name.server.luau` | `Script` |
| `Name.client.luau` | `LocalScript` |
| `Name.luau` | `ModuleScript` |
| `Name/init.server.luau` | `Script` with children |
| `Name/init.client.luau` | `LocalScript` with children |
| `Name/init.luau` | `ModuleScript` with children |

`place.json` maps local service directories back to Studio. Push rejects files
outside those mappings.

## Safe JSON and source input

Short JSON without source text can be passed inline. For multiline source,
Unicode, quotes, backslashes, dollar signs, or backticks, use a UTF-8 file or
stdin instead of adding PowerShell escapes:

```powershell
node cli.js plugin call set_properties --json-file .\command.json
node cli.js execute --file .\diagnostic.luau
```

For normal mapped script updates, avoid source-bearing JSON entirely: edit the
local file and use `push`.

## GitHub repository context

Run the command inside a GitHub checkout to discover its `origin`:

```powershell
node cli.js github-context
node cli.js github-context --json
```

Pass another public repository explicitly when needed:

```powershell
node cli.js github-context velumix/Nerve
```

The provider uses GitHub's REST API to read repository metadata, the latest
default-branch commit and release, open pull requests, and recent Actions runs.
Public repositories work without authentication at GitHub's lower anonymous
rate limit. Set `GITHUB_TOKEN` or `GH_TOKEN` for private repositories or higher
limits. Tokens are read from the environment and are not persisted or included
in output.

`ai-context` automatically appends this data when the active project has a
GitHub origin. GitHub API failure does not block Studio context, but the direct
`github-context` command reports authentication, permission, and repository
errors.

## Safety and completion rules

- Inspect before changing live Studio state.
- Keep edits narrow; do not run broad find/replace without explicit approval.
- Do not restart or close Studio until unsaved work is protected.
- Do not overwrite a live script merely to test connectivity.
- Preserve and restore exact original source when a reversible test is needed.
- Keep Abraxius.App running unless the user asks to quit.
- Never claim a push succeeded without verified or explicitly pending output.
- Treat `pending: true` as completion for the push command. Do not push the same
  file again or run `pending verify` until the draft is committed.

## Troubleshooting order

```powershell
node cli.js status
node cli.js plugin status
node cli.js plugin events 20
```

- Host offline: launch the registered Abraxius app or run `npm run app:run`.
- Companion offline: enable Studio HTTP requests, install the plugin with
  `npm run install-plugin`, and restart Studio only after protecting work.
- MCP unavailable: reconnect the Studio MCP transport; do not substitute a
  whole-script write.
- Push reports pending: wait for the user to commit the Draft Mode edit. Then
  inspect `node cli.js pending` and use `pending verify` only if still needed.

## Reference map

- [AXL](axl.md): compact typed AI command language
- [Windows app](windows-app.md): pages, lifecycle, and UI behavior
- [CLI reference](cli.md): complete command syntax
- [Sync workflow](sync.md): mapping and Draft Mode details
- [API reference](api.md): local HTTP endpoints and transports
- [AI context](ai-context.md): briefings and durable memory
- [AI agent skill](agent-skill.md): universal discovery, trigger, and guarantees

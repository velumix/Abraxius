---
name: abraxius-studio-sync
description: Use Abraxius to inspect Roblox Studio, pull scripts into a local project, edit mapped Luau files, push them back automatically, and verify or roll back changes. Trigger whenever the user says to use Abraxius, sync with Studio, push or pull Roblox scripts, troubleshoot the companion, or edit a pulled Studio project.
---

# Abraxius Studio Sync

Use the repository's running Abraxius host and companion channel. Treat Studio as
live user state: inspect first, scope edits narrowly, and track every push to
verification or an explicit Draft Mode pending state.

## Default AI-agent workflow

When the user asks an AI agent to use Abraxius for a script change:

1. Inspect or pull the target when its current mapping is unknown.
2. Edit the mapped local `.luau` file with the normal file-editing tools.
3. Run exactly one high-level push command for that file:

   ```powershell
   node cli.js push <mapped-file>
   ```

4. Report `verified: true` or `pending: true` exactly as returned by Abraxius.
   Treat pending as an accepted push and do not retry it.

Do not make the model calculate diffs, construct `multi_edit` payloads, escape
Luau source into a shell, create scripts manually, or perform a second
read-back for a normal successful push. `push` owns source discovery, targeted
edit generation, new-script creation, MCP `multi_edit`, and pending tracking.

## Check prerequisites

Run from the Abraxius repository root.

```powershell
Invoke-RestMethod http://127.0.0.1:13470/health
rust\abraxius-rs\target\release\abraxius.exe plugin status
```

Require `running: true` and `pluginConnected: true` for companion sync. The
WinUI app owns the Rust daemon and ports `13469`-`13471`; the CLI is only a
client and must not start or stop a separate host.

If the host is offline, launch the registered Windows app or run:

```powershell
npm run app:run
```

## Inspect Studio

Confirm the target before pulling or changing it.

```powershell
rust\abraxius-rs\target\release\abraxius.exe plugin inspect ServerScriptService
rust\abraxius-rs\target\release\abraxius.exe plugin inspect ReplicatedStorage
node cli.js plugin call read_source '{"path":"game.ServerScriptService.KnitServer"}'
```

Use dot-separated Studio paths. The companion accepts paths with or without the
leading `game.` segment.

## Pull scripts

Pull the full open place into a dedicated directory:

```powershell
node cli.js pull game
```

The full pull uses the companion's bulk export and writes `place.json` plus
`src/`. Never pull into a directory containing unrelated uncommitted files.

Targeted pulls use MCP and fail while the MCP transport is offline:

```powershell
node cli.js pull --target ServerScriptService.KnitServer game
```

## Push a script

Edit only files inside a pulled project, then push the exact file:

```powershell
node cli.js push game\src\ServerScriptService\KnitServer.server.luau
```

Script pushes require MCP and the companion. The single command above reads the
exact source, calculates targeted edits, applies them through MCP `multi_edit`,
creates a missing script when needed, and records the intended source. A changed
script normally returns `pending: true`; this means MCP accepted it. Never
replace this high-level workflow with `write_source`, direct `.Source`
assignment, manually authored `multi_edit` calls, or a whole-file replacement
fallback.

## Interpret, verify, and recover

For `verified: true`, finish normally. For `pending: true`, do not retry the
push, read the source back, or run `pending verify` immediately. Draft Mode can
expose only the last committed source and can hang immediate verification.

After the user commits the draft, inspect pending state and verify only if the
companion source-change event has not already cleared it:

```powershell
node cli.js pending
node cli.js pending verify
```

Use manual `read_source` only after commit when diagnosing a disputed result.
Do not test connectivity by changing an existing live script. If the user asks
for a push test, use a uniquely named disposable mapped script and remove only
that exact test artifact and its pending record afterward.

## Safety rules

- Do not restart or close Studio without checking for unsaved work.
- Do not use broad find/replace operations unless the user explicitly approves.
- Do not overwrite a live script merely to test connectivity. When the user
  requests a push test, use and remove an exact disposable test artifact.
- For JSON containing source, quotes, backslashes, PowerShell metacharacters, or
  Unicode, use `--json-file`/`--json-stdin`; use `--file`/`--stdin` for Luau.
  Do not retry malformed inline payloads by stacking more shell escapes.
- Do not claim success unless the push result reports `verified: true` or
  `pending: true`. Pending is successful acceptance, but not proof of commit.
- Never retry a pending push. Wait for the user to commit the draft before
  manual verification.
- Keep the Abraxius app running after verification unless the user asks to quit.

Read [references/commands.md](references/commands.md) for the transport matrix,
file mapping, and troubleshooting commands.

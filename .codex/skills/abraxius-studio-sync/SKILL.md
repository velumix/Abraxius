---
name: abraxius-studio-sync
description: Operate the Abraxius Windows host, Rust daemon, and Roblox Studio companion to inspect Studio, pull scripts into a local project, push existing script edits back, and verify or roll back changes. Use for Abraxius health checks, Roblox Studio script sync, companion troubleshooting, safe pull/push workflows, and edits to pulled Luau projects.
---

# Abraxius Studio Sync

Use the repository's running Abraxius host and companion channel. Treat Studio as
live user state: inspect first, scope edits narrowly, and verify every push.

## Check prerequisites

Run from the Abraxius repository root.

```powershell
Invoke-RestMethod http://127.0.0.1:13470/health
rust\abraxius-rs\target\release\abraxius.exe plugin status
```

Require `running: true` and `pluginConnected: true` for companion sync. Do not
start the Node daemon when the WinUI app's Rust daemon already owns ports
`13469`-`13471`.

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

## Push an existing script

Edit only files inside a pulled project, then push the exact file:

```powershell
node cli.js push game\src\ServerScriptService\KnitServer.server.luau
```

When MCP is offline, Abraxius updates an existing script through the companion
and immediately reads the source back. Creating a new Studio script still
requires MCP.

## Verify and recover

Read the Studio source after every push and compare it with the local file.

```powershell
node cli.js plugin call read_source '{"path":"game.ServerScriptService.KnitServer"}'
```

For a test push, preserve the exact original source, add one unique comment,
push and verify it, then restore the original and push again. Confirm the final
source is an exact match. Do not leave test markers in Studio.

## Safety rules

- Do not restart or close Studio without checking for unsaved work.
- Do not use broad find/replace operations unless the user explicitly approves.
- Do not overwrite a live script merely to test connectivity; use a reversible
  marker and restore it in the same task.
- Do not claim a push succeeded from CLI output alone; read Studio back.
- Keep the Abraxius app running after verification unless the user asks to quit.

Read [references/commands.md](references/commands.md) for the transport matrix,
file mapping, and troubleshooting commands.

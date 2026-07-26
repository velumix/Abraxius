# Codex Skill

Abraxius includes a repository-local Codex skill at:

```text
.codex/skills/abraxius-studio-sync
```

Ask Codex to **use Abraxius** or name `$abraxius-studio-sync` when inspecting
Roblox Studio, pulling a place, updating a mapped Luau script, pushing it back,
or diagnosing the app and companion. Either phrase triggers the same workflow.

The canonical operating instructions are in [AI Guide: Using
Abraxius](ai-usage.md). The skill enforces that guide inside this repository;
this page only explains how to trigger it.

## Example requests

```text
Use $abraxius-studio-sync to pull the open place into game/.
Use $abraxius-studio-sync to update KnitServer and track the pushed source.
Use $abraxius-studio-sync to diagnose why the companion is disconnected.
Use Abraxius to change the sword controller and push it to Studio.
```

## Normal script-change workflow

Codex edits the mapped local file and runs one command:

```powershell
node cli.js push game\src\ServerScriptService\KnitServer.server.luau
```

That command reads Studio, calculates narrow edits, calls MCP `multi_edit`,
creates the script if needed, and tracks the intended source as pending. In
Draft Mode, Codex treats `pending: true` as accepted and waits for commit instead
of retrying or reading the hidden draft back. See the AI guide for preflight,
Command Center use, Draft Mode, and recovery.

## Workflow guarantees

The skill directs an agent to:

- verify the Windows host, Rust daemon, and companion before editing
- inspect the intended Studio path first
- pull into a dedicated project directory
- push only a file mapped by `place.json`
- use one high-level push command per changed file
- let Abraxius generate `multi_edit` operations and track pending source
- never retry or immediately verify a Draft Mode pending push
- restore temporary test edits before finishing

The detailed command and transport reference lives with the skill so it remains
versioned with the implementation.

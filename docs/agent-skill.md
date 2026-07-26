---
sidebar_position: 12
sidebar_label: Agent skill
---

# AI Agent Skill

Abraxius provides model-neutral operating instructions in:

```text
AGENTS.md
docs/ai-usage.md
```

Any AI client can follow those files or call Abraxius through its CLI and local
API. The reusable skill package is available at:

```text
skills/abraxius-studio-sync
```

Hosts that use product-specific discovery directories can point an adapter at
that canonical package. The repository includes one such adapter at
`.codex/skills/abraxius-studio-sync`; it contains no separate workflow. The
skill is not tied to Codex, OpenAI, or any particular model.

Ask an AI to **use Abraxius** or, in skill-aware clients, name
`$abraxius-studio-sync` when inspecting Roblox Studio, pulling a place,
updating a mapped Luau script, pushing it back, or diagnosing the app and
companion. Both forms use the same workflow.

The canonical operating instructions are in [AI Guide: Using
Abraxius](ai-usage.md). The skill packages that guide for compatible agent
hosts; this page only explains how integrations discover it.

## Example requests

```text
Use $abraxius-studio-sync to pull the open place into game/.
Use $abraxius-studio-sync to update KnitServer and track the pushed source.
Use $abraxius-studio-sync to diagnose why the companion is disconnected.
Use Abraxius to change the sword controller and push it to Studio.
```

## Normal script-change workflow

The AI agent edits the mapped local file and runs one command:

```powershell
node cli.js push game\src\ServerScriptService\KnitServer.server.luau
```

That command reads Studio, calculates narrow edits, calls MCP `multi_edit`,
creates the script if needed, and tracks the intended source as pending. In
Draft Mode, the agent treats `pending: true` as accepted and waits for commit
instead of retrying or reading the hidden draft back. See the AI guide for
preflight, Command Center use, Draft Mode, and recovery.

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

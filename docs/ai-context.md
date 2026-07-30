---
sidebar_position: 6
sidebar_label: AI context and memory
---

# AI Context and Memory

Abraxius makes AI context explicit. Instead of asking an AI agent to infer the
project from scattered commands, use `node cli.js ai-context` as the first
briefing for every session. See [AI Guide: Using Abraxius](ai-usage.md) for the
complete operating workflow.

## What the briefing contains

`node cli.js ai-context` produces a compact Markdown snapshot with:

- pinned project memory from `.abraxius/memory.json`
- active project directory and preferred DataModel
- recent scripts touched through Abraxius
- recent tool calls, edits, and executions
- pending Studio pushes and Draft Mode verification status
- companion plugin connection state
- recent Studio events such as selection and source changes
- current selection, active/open scripts, service sizes, script counts, and tags
- source hashes, hierarchy batches, play-mode transitions, warnings, and errors
- ChangeHistory recordings, undo, and redo activity
- GitHub repository metadata, pull requests, releases, commits, and Actions
  runs when the project has a GitHub origin

Source changes are debounced into edit sessions after 1.25 seconds of inactivity.
Each event includes the original and final source hashes, final source length,
underlying change count, and session duration instead of one event per keystroke.

Use JSON when another tool needs structured data:

```bash
node cli.js ai-context --json
```

## GitHub context

Read only the repository briefing:

```bash
node cli.js github-context
node cli.js github-context --json
node cli.js github-context velumix/Nerve
```

Abraxius discovers the repository from the nearest Git checkout's `origin`.
Public repositories work anonymously. Set `GITHUB_TOKEN` or `GH_TOKEN` when
private access or a higher API rate limit is needed. The token is read from the
environment and never stored or returned in the briefing.

The provider uses Octokit and GitHub's versioned REST API. It collects:

- repository description, visibility, default branch, license, stars, and forks
- the latest commit on the default branch
- up to five recently updated open pull requests
- up to five recent GitHub Actions runs
- the latest published release when one exists

GitHub context is best effort inside `ai-context`, so a network or permission
failure never prevents Studio context from loading. Use `github-context`
directly when an API failure should stop the command and return an error.

## Pin durable memory

Pinned memory is for facts that should survive daemon restarts and future AI sessions.

Good memory entries are specific and durable:

```bash
node cli.js remember "MatchManager owns round flow; do not move phase timing into UI clients." --tag architecture --path ServerScriptService.MatchManager
node cli.js remember "Prefer small focused Luau modules over large manager rewrites." --tag preference
```

List memory:

```bash
node cli.js memory
```

Clear one entry by id:

```bash
node cli.js memory clear <id>
```

Clear all memory:

```bash
node cli.js memory clear
```

## Project-specific memory

By default, memory is stored under the current working directory:

```text
.abraxius/memory.json
```

Use `--project` when working outside the project root:

```bash
node cli.js remember "InventoryService is the source of truth for inventory writes." --project ./game --tag architecture
node cli.js ai-context --project ./game
```

## How AI agents should use it

Treat pinned memory as durable project facts unless the user corrects it. Treat recent operations and Studio events as useful short-term context that may be stale. Always check pending pushes before assuming Studio has committed local edits.

## In-app task retrieval

Studio Copilot uses `context "<task>" budget=N` through AXL before each model
request. AXL ranks live scripts against distinctive terms in the task and
returns compact matching lines before a bounded Studio-state snapshot. This is
the default in-app path because it gives small local models relevant evidence
without repeatedly sending the entire place snapshot. The full snapshot
remains available as an explicit supplement.

When **Research mode** is enabled, Studio Copilot may follow the initial
briefing with at most two structured planning rounds. Each proposal is
validated against a fixed read-only allowlist before Abraxius sends compact AXL
text to Studio. The loop permits no more than six deduplicated `find`,
`read … symbols`, bounded `read … lines`, or `state` calls and stops after
approximately 2,000 evidence tokens. Planning failure falls back to ordinary
chat, and mutations remain in the separately approved Commands workflow.

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

Source changes are debounced into edit sessions after 1.25 seconds of inactivity.
Each event includes the original and final source hashes, final source length,
underlying change count, and session duration instead of one event per keystroke.

Use JSON when another tool needs structured data:

```bash
node cli.js ai-context --json
```

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

# AI Context and Memory

Abraxius makes AI context explicit. Instead of asking an AI agent to infer the project from scattered commands, use `mcp ai-context` as the first briefing for every session.

## What the briefing contains

`mcp ai-context` produces a compact Markdown snapshot with:

- pinned project memory from `.abraxius/memory.json`
- active project directory and preferred DataModel
- recent scripts touched through Abraxius
- recent tool calls, edits, and executions
- pending Studio pushes and Draft Mode verification status
- companion plugin connection state
- recent Studio events such as selection and source changes

Use JSON when another tool needs structured data:

```bash
mcp ai-context --json
```

## Pin durable memory

Pinned memory is for facts that should survive daemon restarts and future AI sessions.

Good memory entries are specific and durable:

```bash
mcp remember "MatchManager owns round flow; do not move phase timing into UI clients." --tag architecture --path ServerScriptService.MatchManager
mcp remember "Prefer small focused Luau modules over large manager rewrites." --tag preference
```

List memory:

```bash
mcp memory
```

Clear one entry by id:

```bash
mcp memory clear <id>
```

Clear all memory:

```bash
mcp memory clear
```

## Project-specific memory

By default, memory is stored under the current working directory:

```text
.abraxius/memory.json
```

Use `--project` when working outside the project root:

```bash
mcp remember "InventoryService is the source of truth for inventory writes." --project ./game --tag architecture
mcp ai-context --project ./game
```

## How AI agents should use it

Treat pinned memory as durable project facts unless the user corrects it. Treat recent operations and Studio events as useful short-term context that may be stale. Always check pending pushes before assuming Studio has committed local edits.

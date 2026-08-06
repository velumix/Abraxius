---
sidebar_label: Local AI
---

# Local AI

The AI workspace is a local, read-only Studio Copilot. It answers from selected
evidence and can prepare reviewable command plans, but it has no shell,
filesystem, or Studio mutation tool.

## Provider setup

Start Ollama on its default local endpoint:

```text
http://127.0.0.1:11434
```

Open **AI**, refresh models, and choose a local model. The recommended coding
baseline is `qwen2.5-coder:7b`. Cloud-backed Ollama entries are labeled and
hidden while **Local models only** is enabled.

## Context controls

| Control | Purpose |
|---|---|
| Task-aware AXL retrieval | Finds evidence relevant to the current prompt |
| AXL token budget | Caps the retrieved Studio context |
| Research mode | Allows bounded multi-round read-only investigation |
| Full Studio snapshot | Adds the larger generic snapshot; off by default |
| Unsaved active editor source | Includes the current local buffer |
| Runtime errors and warnings | Includes recent diagnostic evidence |

Use **Preview assembled context** to see what will be sent before asking the
model.

## Research mode

Research mode permits at most:

- two planning rounds
- six validated AXL reads
- about 2,000 evidence tokens

Allowed operations are `find`, `symbols`, bounded `lines`, and `state`. Patch,
execute, undo, and full-source reads are unavailable. The UI records calls,
rounds, and estimated evidence tokens after each run.

## Project instructions and memory

AI state is separated by connected Studio place. Each project can retain:

- project-specific instructions
- explicit pinned memories
- up to 40 redacted conversation messages

**Compact conversation into memory** asks the selected local model for a short
durable summary, saves it as a reviewable memory, and clears the verbose chat
history.

## Draft a command plan

The model can produce structured operation proposals. Abraxius validates every
command name against the live schema catalog and adds valid proposals to the
Commands approval queue.

The model never executes the plan. Review the exact arguments in
[Change Review](app-change-review.md).

## Token efficiency

Abraxius avoids resending the entire place:

1. AXL scouts for prompt-relevant paths and symbols.
2. Only bounded evidence enters the request.
3. Conversation history is trimmed to the selected model's context window.
4. Durable facts can be compacted into project memory.
5. The UI reports estimated input/output tokens and response time.

For the underlying briefing and memory formats, see
[AI context and memory](ai-context.md).

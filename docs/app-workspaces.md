---
sidebar_label: Workspace tour
---

# Workspace tour

The navigation rail separates observation, editing, approval, automation, and
diagnostics. At narrower window sizes the rail collapses and secondary panes
move or hide so the active task keeps the available space.

## Home

Home is the readiness dashboard. It shows the independent host, MCP, and
companion states, plus server controls and runtime information.

Use Home when:

- Studio actions are unavailable
- you need to restart only the Rust host
- you want to copy a compact status summary
- you need logs or the local data directory

## Activity

Activity follows the current or most recent playtest. It presents session
duration, errors, warnings, prints, runtime output, memory, players, physics,
and scene information gathered by the companion.

Collection is local. Disable detailed play data from Settings or the companion
when you do not want output and source activity retained.

## Intelligence

Intelligence correlates persistent Studio signals:

- repeated errors and warning spikes
- recent script edits near a failure
- memory and physics anomalies
- instance and player transitions

Suggestions include evidence and confidence. Classification uses the configured
small local model only when requested; escalation to the larger model is also
explicit.

## Sync

Sync shows watched scripts, recent source changes, the current Studio mode, and
the bounded source-activity feed. It is an observation page and does not push
files.

For filesystem mappings and CLI pushes, read [Sync workflow](sync.md).

## Code

Code embeds a locally bundled Monaco editor for Luau:

- synchronized Studio script explorer
- multiple guarded tabs
- source hashes and conflict detection
- dry-run preview
- find, replace, go to line, and command palette
- optional StyLua formatting
- optional `luau-analyze` diagnostics
- local recovery of open tabs and dirty buffers

**Review change** stages the active dirty buffer. It does not change Studio.
The actual apply action lives in [Change Review](app-change-review.md).

## Review

Review combines dirty Code buffers and queued Commands operations. It is the
approval boundary for mutations and shows:

- target and operation type
- deterministic risk level
- intended effect
- preflight result
- exact dry-run diff or JSON arguments

See [Change Review](app-change-review.md) for the complete workflow.

## Commands

Commands is the manual Studio operation builder. Start from a common task or
browse the live companion catalog. Safe reads can run directly; mutations must
be added to Change Review.

See [Commands](app-commands.md).

## AI

AI is a read-only local Copilot workspace. It can retrieve bounded Studio
evidence through AXL, include selected local context, retain project memory, and
draft schema-valid operations into the approval queue. The model cannot apply
those operations.

See [Local AI](app-ai.md).

## Diagnostics

Diagnostics filters Studio output into errors, warnings, and informational
entries. It can also generate a redacted support bundle without source,
conversation, or project-memory contents.

## Settings

Settings controls startup, host supervision, local storage, logs, play-data
collection, and support bundles. Use **Quit Abraxius** from the tray menu when
you intend to stop both the app and its Rust host.

---
sidebar_position: 13
sidebar_label: Product roadmap
---

# Abraxius Workspace Roadmap

This checklist tracks the evolution of Abraxius from a Studio supervisor into
a safe, AI-assisted Roblox development workspace.

## Product principles

- [ ] Keep Studio as the source of truth and verify every mutation by read-back.
- [ ] Default to observe and preview; require explicit approval for mutations.
- [ ] Present plain-language workflows while keeping raw commands available.
- [ ] Use one provider-neutral interface for hosted, CLI, and local models.
- [ ] Bound agents by project roots, Studio paths, commands, and time budgets.
- [ ] Preserve a complete local history of commands, diffs, and outcomes.

## Phase 1: Command workspace

- [x] Add a dedicated Commands destination to the Windows app.
- [x] Discover commands from the companion's machine-readable schemas.
- [x] Allow raw JSON arguments for every discovered command.
- [x] Show formatted results and retain an in-session command history.
- [x] Require confirmation before known mutating or executable commands.
- [x] Generate editable starter JSON from required schema fields and enums.
- [x] Add command search, categories, favorites, and recently used commands.
- [x] Add persistent saved command presets.
- [x] Generate dedicated structured controls for each JSON schema property.
- [x] Add reusable multi-command workflows.
- [x] Add dry-run and diff presentation for supported mutations.
- [x] Add an approval queue with atomic batches for compatible operations.
- [x] Persist command history with redaction and retention controls.

## Phase 2: Code workspace

- [x] Embed a locally bundled Monaco editor through WebView2 with Luau syntax support.
- [x] Add a synchronized Studio script explorer with filtering and refresh.
- [x] Support tabs, find/replace, go-to-line, and command palette navigation.
- [x] Pull source with hashes and preserve the Studio path mapping.
- [x] Show the companion's structured source diff before push.
- [x] Detect Studio conflicts through optimistic source hashes.
- [x] Push through dry-run, approval, commit, and read-back verification.
- [x] Add formatting and diagnostics adapters for StyLua and Luau tooling.
- [x] Add file/session recovery and unsaved-buffer guards.

## Phase 3: AI provider platform

- [x] Define provider-neutral model discovery, streaming chat, and cancellation contracts.
- [ ] Add an OpenAI-compatible HTTP provider.
- [x] Add Ollama health, discovery, model selection, streaming chat, and cancellation.
- [ ] Add guarded CLI adapters for Codex and Kimi Code.
- [x] Add provider health, latency, estimated-token, context, and local/cloud indicators.
- [x] Build opt-in curated context from Studio state, active editor source, and runtime output.
- [x] Add per-project instructions and explicit long-term memory.
- [x] Add per-project conversation persistence and sensitive-data redaction.
- [x] Add local-model conversation compaction into reviewable project memory.
- [x] Add deterministic redacted conversation and project-memory export.
- [x] Add local-model compact agent briefings for low-token handoff.
- [x] Add schema-validated AI command proposals routed into the approval queue.
- [x] Keep the initial provider workspace read-only with no shell, filesystem, or mutation tools.

## Phase 4: Studio intelligence

- [x] Create a timeline for edit/play/server/client transitions.
- [x] Detect new errors, warning spikes, and repeated stack traces.
- [x] Correlate runtime failures with recent script changes.
- [x] Track memory, physics, instance, and player-count anomalies.
- [x] Use a small local model for classification and concise summaries.
- [x] Add a suggestion inbox with evidence, confidence, and dismiss controls.
- [x] Escalate to a larger model only when explicitly requested.
- [x] Add quiet hours, notification thresholds, and per-signal controls.

## Phase 5: Safe agent mode

- [ ] Support Observe, Assist, and Agent operating modes.
- [ ] Add Studio-path and local-project allowlists.
- [ ] Add command allow/deny policies and destructive-operation gates.
- [ ] Require plans and previews before multi-step mutations.
- [ ] Execute compatible changes as atomic batches with rollback.
- [ ] Enforce step, token, duration, and retry budgets.
- [ ] Provide stop, pause, undo, and emergency-disable controls.
- [ ] Produce an auditable execution report with verification evidence.

## Release readiness

- [ ] Add view models/services so UI, transport, and provider logic are isolated.
- [ ] Add unit tests for schema parsing, policies, diffs, and provider adapters.
- [ ] Add integration tests against a simulated companion session.
- [ ] Add accessibility names, keyboard navigation, and high-contrast coverage.
- [x] Add adaptive fill layouts and compact/medium/wide breakpoints across the Windows app.
- [ ] Package model/provider settings securely using Windows credential storage.
- [ ] Document data flow, threat model, recovery, and troubleshooting.
- [x] Add privacy-filtered diagnostics bundles with bounded logs and retention.

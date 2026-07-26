# Abraxius agent guide

Read [docs/ai-usage.md](docs/ai-usage.md) before operating Abraxius or Roblox
Studio. It is the canonical workflow and transport reference for AI agents.

Core rules:

1. Treat the open Studio place as live user state. Inspect before mutation.
2. For normal script work, edit the mapped local Luau file and run exactly one
   `node cli.js push <mapped-file>` command. The push generates `multi_edit` and
   verifies Studio; do not hand-build the edit payload.
3. Use Command Center `multi_edit` only for an explicitly requested manual,
   exact replacement. Its JSON needs only `file_path` and `edits`; the app adds
   `datamodel_type: "Edit"`.
4. A push is complete only when Abraxius reports `verified: true`, or explicitly
   reports a tracked Draft Mode `pending` state.
5. Treat `pending: true` as an accepted push. Do not retry, immediately read the
   source, or run `pending verify` before the user commits the draft in Studio.
   Verify only after commit or rely on the companion's source-change event.
6. Do not restart or close Roblox Studio without protecting unsaved work.

The repository may contain unrelated uncommitted work. Preserve it.

# Codex Skill

Abraxius includes a repository-local Codex skill at:

```text
.codex/skills/abraxius-studio-sync
```

Use `$abraxius-studio-sync` when asking Codex to inspect Roblox Studio, pull a
place, update a pulled Luau script, push it back, or diagnose the Abraxius app
and companion connection.

## Example requests

```text
Use $abraxius-studio-sync to pull the open place into game/.
Use $abraxius-studio-sync to update KnitServer and verify the pushed source.
Use $abraxius-studio-sync to diagnose why the companion is disconnected.
```

## Workflow guarantees

The skill directs an agent to:

- verify the Windows host, Rust daemon, and companion before editing
- inspect the intended Studio path first
- pull into a dedicated project directory
- push only a file mapped by `place.json`
- read the live Studio source back after every push
- restore temporary test edits before finishing

The detailed command and transport reference lives with the skill so it remains
versioned with the implementation.

# Abraxius agent profiles

Abraxius separates repository development from Roblox Studio work. This keeps
an agent that is editing Abraxius from being limited to Studio tools, while a
Studio-focused agent does not receive unnecessary repository or shell access.

## Abraxius Developer Agent

Use this profile when the agent is working on Abraxius itself. It needs:

- filesystem read/write and directory listing
- shell/terminal execution
- Git status, diff, and commit operations
- repository editing
- Abraxius MCP access through `node cli.js stdio`

Launch it from the repository root:

```sh
cd /path/to/Abraxius
antigravity
```

The active repository is the current working directory. The profile contract
is stored in `.abraxius/agent-profiles.json`.

## Roblox Studio Agent

Use this profile for live Studio work. It receives Roblox DataModel access,
Roblox scripts and instances, Studio tests, and Creator Store operations. It
does not receive arbitrary repository filesystem, shell, or Git capabilities.

Normal script changes still follow the mapped-file workflow in
[`docs/ai-usage.md`](ai-usage.md): edit the mapped local Luau file and run one
`node cli.js push <mapped-file>` command.

## Important boundary

Do not give the Abraxius repository-development prompt to the Roblox-only
agent. Do not give the Studio mutation toolbox to a repository agent unless
the task explicitly requires it and the user approves the operation.

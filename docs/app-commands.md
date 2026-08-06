---
sidebar_label: Commands
---

# Commands

Commands turns the live companion command schema into a task-first form. The
catalog is discovered from the connected Studio session, so the available
operations match the installed companion.

## Start with a task

The common-task buttons cover the usual entry points:

| Task | Command | Behavior |
|---|---|---|
| Inspect selection | `get_selection` | Read-only; can run immediately |
| Read a script | `read_source` | Read-only; requires a Studio path |
| Inspect properties | `get_properties` | Read-only; requests selected properties |
| Create a script | `create_script` | Mutation; must enter Change Review |
| Edit a script | `multi_edit` | Mutation; exact replacements through MCP |
| Change properties | `set_properties` | Mutation; must enter Change Review |

Use search and category filters for the complete catalog. Raw JSON and the live
schema remain under **Advanced JSON and schema**.

## Fill in the form

Required fields are marked with an asterisk. Structured controls update the JSON
payload automatically.

Common path forms:

```text
ServerScriptService.Main
game.ReplicatedStorage.Modules.Inventory
Workspace.TestPart
```

For `create_script`, provide either a full `path`, or `parent` plus `name`.

## Run or review

- **Run inspection** is enabled for read-only commands.
- **Add to Change Review** stages any operation for inspection.
- Mutating or executable commands show **Review required** and cannot use the
  direct Run action.

The approval queue is a staging area. **Open Change Review** moves to the
dedicated approval surface; it does not execute the queue.

## Exact script replacements

`multi_edit` is the app-provided MCP command:

```json
{
  "file_path": "game.ServerScriptService.Main",
  "edits": [
    {
      "old_string": "local speed = 10",
      "new_string": "local speed = 20"
    }
  ]
}
```

Edits run in order and are atomic. `old_string` must match exactly. Add
`replace_all: true` only when every match should change.

For ordinary coding-agent changes to a pulled project, do not hand-author this
payload. Edit the mapped local file and use one high-level
`node cli.js push <file>` command instead.

## Presets, workflows, and history

- **Presets** save arguments for one command.
- **Workflows** save the current approval queue for later reuse.
- **Command history** stores bounded, redacted outcomes with configurable
  retention.

Sensitive values are redacted before persistence. Source code should still be
kept out of preset names and workflow labels.

## Discovery timing

Health polling uses a short timeout, but Studio command discovery and execution
use a separate 35-second bound. If an older build reports a one-second
`HttpClient.Timeout`, update to Abraxius App 1.15.1 or newer.

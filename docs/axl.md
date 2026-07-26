---
sidebar_position: 8
sidebar_label: AXL command language
---

# AXL: Abraxius Exchange Language

AXL is a compact, typed command language for AI-to-Abraxius communication. It
is deliberately not a general-purpose programming language. The Roblox Studio
companion parses commands, resolves live instances, validates source revisions,
and performs Studio operations. The app and CLI only transport the compact
text and return the compact response.

AXL/1 Core is experimental. Path targets are executable today. The parser
reserves namespace (`@`), symbol (`#`), context (`$`), operation (`%`), and
namespace-version (`^`) identifiers, but ID resolution and structural Luau
editing are future layers. Unresolved IDs fail with `ERR NONAMESPACE`; they
never fall back to guessing a path.

## Run AXL

Use one inline command:

```powershell
node cli.js axl 'read game.ServerScriptService.MatchManager summary'
```

Use a UTF-8 file for patches or multiline Luau:

```powershell
node cli.js axl --file .\change.axl
```

Or pipe an exact command:

```powershell
Get-Content -Encoding UTF8 -Raw .\change.axl | node cli.js axl --stdin
```

Parse without executing for debugging and integration tests:

```powershell
node cli.js axl --ast 'read #41 ^9 source'
```

## AXL/1 Core grammar

```text
command  = hello | context | find | read | patch | execute | state | undo

hello    = "hello" ["axl/1"] ["project=" value]
context  = "context" quoted ["budget=" integer]
find     = "find" quoted ["budget=" integer]
read     = "read" target ["summary" | "symbols" | "source" | "full"
                         | "lines" range]
patch    = "patch" target-with-revision newline old-block new-block
execute  = "execute" (quoted | heredoc) ["mode=" ("Edit" | "Client" | "Server")]
state    = "state" [target]
undo     = "undo" operation-id

target   = studio-path | "@" integer | "#" integer | "$" integer | "%" integer
range    = integer ".." integer
```

Quoted strings support single or double quotes. Backslash escapes are accepted
inside quotes. Commands are case-insensitive; option names are not.

## Commands

### Handshake

```text
hello axl/1 project=4
```

Current companion response:

```text
READY axl/1 ns=0 tools=core,studio
```

`ns=0` means the namespace resolver is not enabled yet.

### Context

```text
context "round can end twice" budget=700
```

The budget is an approximate output-token ceiling, from 64 to 32,000. Abraxius
returns a bounded AI context briefing:

```text
CTX $18422112 t=694
...
```

### Find

```text
find "EndRound" budget=500
```

The companion scans live `LuaSourceContainer` instances in Studio and bounds
the returned paths and line numbers to the requested budget.

### Read

```text
read game.ServerScriptService.MatchManager summary
read game.ServerScriptService.MatchManager symbols
read game.ServerScriptService.MatchManager source
read game.ServerScriptService.MatchManager lines 84..143
```

`summary` returns counts without source. `symbols` returns deterministically
detected function names and line numbers. `source` and `full` return full source.
`lines` returns only the selected range. Every source-derived response includes
a numeric revision computed from the exact source:

```text
SRC game.ServerScriptService.MatchManager@308937084 84..143 t=432
```

### Patch

Patch is an exact, revision-checked replacement. It is the only source mutation
in AXL/1 Core:

```text
patch game.ServerScriptService.MatchManager@308937084
old <<OLD
local speed = 10
OLD
new <<NEW
local speed = 20
NEW
```

Before mutation, the companion reads the exact live source and checks the
revision. The old text must occur exactly once. The plugin applies the change
with `ScriptEditorService` and owns the ChangeHistory recording:

```text
OK %91 game.ServerScriptService.MatchManager@133704925 changed=0 pending=1
```

`pending=1` means `ScriptEditorService` accepted the edit while Studio Draft
Mode still exposes the previous committed `Instance.Source`. Do not retry it.
After the draft is committed, a direct edit reports `verified=1`.

No host-side read, diff, or MCP edit round trip is involved. The plugin owns
the live operation and reports Studio's draft state directly.

### Execute

```text
execute "return workspace:GetServerTimeNow()" mode=Edit
```

Multiline form:

```text
execute <<LUAU mode=Edit
print(workspace.Name)
return true
LUAU
```

AXL/1 currently executes in Studio Edit mode. Client and Server execution modes
are reserved and return `ERR UNSUPPORTED`.

### State

```text
state
state game.Workspace.Baseplate
```

The no-target form reads companion-observed Studio state. A path target resolves
the instance and returns its identity. Explicit property selection will be
added with the structural level.

### Undo

```text
undo %91
```

AXL/1 parses operation IDs but deliberately returns `ERR UNSUPPORTED` for undo
execution until each operation owns a verified ChangeHistory recording. It does
not invoke a global blind undo.

## Compact errors

```text
ERR STALE expected=17 current=19 Target revision changed
ERR NONAMESPACE No namespace entry for #41
ERR AMBIGUOUS Patch old text matches more than once
ERR NOSTUDIO Roblox Studio not connected
ERR NOHOST Cannot connect to the Abraxius daemon
```

## Architecture

```text
AXL text
  -> app/CLI transport
  -> Studio companion parser and validator
  -> live DataModel / ScriptEditorService / ChangeHistory
  -> compact AXL response
```

The host-side JSON AST remains available through `--ast` for debugging and
early validation. Production execution always sends the original AXL text to
the plugin. This keeps Studio as the single authority for paths, source,
revisions, edits, runtime state, and undo history.

The host still owns what Roblox cannot: model interaction, local project files,
transport, authentication, and durable sync/pending records for the normal
mapped-file `push` workflow.

## Planned levels

- **AXL Core:** context, find, read, exact patch, execute, state, guarded undo
- **AXL Namespace:** stable `@`, `#`, `$`, and `%` session identifiers
- **AXL Structural:** replace-symbol, insert-before, rename-symbol, add-require,
  and add-parameter after a Luau parser proves the edit location
- **AXL Raw:** explicit fallback operations for line ranges and diffs

New commands should be added only when realistic task benchmarks show they
reduce total successful-task tokens, including retries and failures.

## Verified Studio behavior

AXL/1 Core was validated end-to-end with Abraxius App 1.14.5 and companion
1.8.1:

1. The app-owned Rust host discovered `axl.core` through companion protocol 6.
2. The plugin created and read a disposable ModuleScript in Studio.
3. A revision-checked patch returned `pending=1` while Draft Mode exposed the
   previous committed source.
4. After the draft was committed, `read` returned the intended source and its
   predicted revision.
5. The disposable instance was deleted, leaving no queued or pending commands.

This test confirms that production AXL text passes through the CLI and
app-owned host while live path resolution, revision hashing, patching, and
Draft Mode detection remain inside the Studio plugin.

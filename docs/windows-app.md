# Windows App

Abraxius.App is a packaged WinUI 3 supervisor for the Rust daemon. It follows
the Windows light, dark, and high-contrast themes and uses the project `Logo`
and `Tray` assets for its app and notification-area identities.

Workspace pages use the full available width and height. Home and Sync cards
stack at compact widths, Commands moves its approval queue below the command
form, Code progressively prioritizes the editor over secondary panes, and the
navigation rail switches between expanded and compact modes. The supported
window floor is 760 by 560 logical pixels.

The app targets **.NET 11**. Until .NET 11 reaches general availability, install
the current .NET 11 Preview SDK before building:

```powershell
winget install Microsoft.DotNet.SDK.Preview
```

## Build and launch

```powershell
npm run app:build
npm run app:run
```

`app:run` registers and launches the development package. The registered
Abraxius entry then appears in Start and can be pinned to the taskbar.

## Lifecycle

- Launch starts and monitors `abraxius-daemon.exe`.
- Closing the window hides it while the app and daemon remain active.
- Reopening from Start or the taskbar restores the existing single instance.
- **Restart server** replaces the daemon without duplicating the app.
- **Quit Abraxius** stops the daemon and exits the app.
- **Start with Windows** registers the packaged startup task.
- **Keep the Rust server running** controls automatic supervision.

## Status cards

The window reports three independent states:

- **Server**: Rust daemon health on port `13470`
- **Roblox Studio**: legacy MCP connection state
- **Companion**: Studio plugin session on port `13471`

Companion-based full pull can work while the MCP card says **Waiting**. Script
push requires both MCP and the companion because Abraxius applies source only
through `multi_edit`. Changed scripts are tracked as pending; normal push avoids
immediate read-back because Draft Mode may expose only committed source.

## Workspace

- **Home** shows readiness and the actions needed to get Studio connected.
- **Activity** focuses on the current playtest and recent runtime output.
- **Intelligence** persists a per-project Studio timeline, detects repeated
  errors and warning spikes, correlates failures with recent script edits, and
  watches memory, physics, instances, and player transitions. Suggestions show
  evidence and confidence and can be dismissed, classified with the local
  `qwen2.5-coder:1.5b` model, or explicitly escalated to the 7B model. Signal
  toggles, thresholds, and optional 10 PM–8 AM quiet hours are user-controlled.
- **Sync** reports source activity from the Studio companion.
- **Code** embeds an offline Monaco Luau editor with pull, dry-run preview,
  conflict detection, push approval, and source read-back verification. Its
  synchronized Studio explorer opens scripts in guarded multi-document tabs;
  Monaco find/replace, go-to-line, and command palette actions are available
  from the editor sidebar. Monaco always uses its dark theme. Open tabs and
  unsaved buffers are recovered locally after a restart. When `stylua.exe` or
  `luau-analyze.exe` are available on `PATH`, the sidebar exposes formatting
  and diagnostics through those tools and reports their availability.
- **Commands** discovers live companion schemas, adds the compact MCP
  `multi_edit` command, renders structured and raw JSON inputs, and runs guarded
  manual operations. Direct mutations require confirmation. Commands can be
  saved as presets, placed in an approval queue, and stored as workflows.
- **AI** connects to Ollama on `127.0.0.1:11434`, discovers available models,
  streams chat with cancellation, and sends only the Studio, editor, and
  runtime context sections explicitly enabled in the sidebar. The initial AI
  workspace is read-only and exposes no shell, filesystem, or Studio mutation
  tools. Local models are filtered and preferred by default; cloud-backed
  Ollama entries are clearly labeled and require disabling **Local models
  only**. The recommended local coding baseline is `qwen2.5-coder:7b`.
  AI state is isolated per connected Studio place under the Abraxius local data
  directory. Project instructions, explicit pinned memories, and the last 40
  redacted conversation messages persist across restarts. **Compact
  conversation into memory** asks the selected local model for a concise
  durable summary, saves it as a reviewable memory item, and clears the verbose
  chat history. The UI reports estimated input/output tokens and response time.
  **Generate compact briefing** produces a redacted Markdown handoff for other
  coding agents and copies it to the clipboard. **Draft command plan** asks the
  local model for structured companion operations, validates every command
  name against the live schema catalog, and places valid proposals in the
  Commands approval queue. The model never executes the proposed operations.
- **Diagnostics** exposes categorized output for troubleshooting and creates a
  one-click support bundle containing redacted health data, analytics, and
  bounded log tails.
- **Settings** contains startup, supervision, logs, local storage controls, and
  the same support-bundle action.

## Command Center for AI-generated operations

Use **Discover** before choosing a command so the schema catalog matches the
connected companion. AI-drafted commands are validated against that catalog and
added to the approval queue; the user must approve execution.

`multi_edit` is the one app-provided MCP command. Its JSON intentionally omits
`datamodel_type` because Abraxius injects `"Edit"` automatically:

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

Use Command Center `multi_edit` for deliberate manual replacements. For a
normal AI change to a pulled script, follow the high-level `push` workflow in
[AI Guide: Using Abraxius](ai-usage.md); it generates edits and tracks pending
Draft Mode changes without putting source-bearing JSON in the model context.

## Support bundles

Support bundles are written to `%LOCALAPPDATA%\Abraxius\diagnostics` and the app
opens the new archive in File Explorer. Abraxius keeps the 10 newest bundles.
The bundle replaces the current username and profile directory, redacts common
authorization/token patterns, and excludes source code, editor buffers,
conversation history, command history, project memory, and provider settings.

Unpackaged development builds copy the tray assets beside the executable. If an
asset is missing, the app records the problem and continues running instead of
letting notification-area initialization terminate the host supervisor.

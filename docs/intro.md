---
sidebar_position: 1
sidebar_label: Start here
---

# Getting started

Abraxius connects professional local development tools to the Roblox Studio
session you are actually working in. It can inspect the live DataModel, export
a place as a mapped Luau project, apply narrow source edits, and keep every
connected AI tool grounded in verified Studio state.

Studio remains the authority. Abraxius observes first, previews mutations, and
tracks source changes until Roblox confirms the committed result.

:::tip The short version
Use Abraxius when you want to edit Roblox projects outside Studio without
giving up Studio-aware validation, selection, history, and Draft Mode safety.
:::

## What ships together

| Layer | Responsibility |
| --- | --- |
| Abraxius.App | Runs the Windows workspace, tray process, settings, diagnostics, editor, and approval surfaces |
| Rust host | Owns the local API, process health, companion queue, and persistent app connection |
| Studio companion | Reads the live DataModel, exports scripts, reports Studio activity, and applies supported operations |
| Node and Rust CLIs | Give people, scripts, and coding agents a stable command surface |
| AI workflow | Combines Studio context, project memory, GitHub context, guarded edits, and pending verification |

## How the pieces connect

```text
Local editor or coding agent
            |
            v
Node CLI / Rust CLI / Abraxius.App
            |
            v
App-owned Rust host on 127.0.0.1:13470
            |
            +---- Studio companion on :13471
            |          |
            |          v
            |     Live Roblox DataModel
            |
            +---- Legacy MCP listener on :13469
```

The app is the only host supervisor. CLIs connect to it as clients and never
start a competing daemon. The Studio companion owns live inspection and
full-place export. Source pushes use revision-aware `multi_edit` operations and
remain tracked when Draft Mode delays committed source visibility.

## Install and connect

```powershell
git clone https://github.com/velumix/Abraxius.git
cd Abraxius
npm install
npm run rust:build
npm run install-plugin
npm run app:run
```

Enable **Allow HTTP Requests** in Roblox Studio under **Game Settings >
Security**, then open a place and verify the connection:

```powershell
node cli.js status
node cli.js plugin status
node cli.js plugin inspect Workspace
```

See [Installation](installation.md) for requirements, Windows package setup,
and connection troubleshooting.

## Pull your first project

Export the open place into a dedicated folder:

```powershell
node cli.js pull game
```

Abraxius writes a `place.json` mapping and a familiar source tree:

```text
game/
|-- place.json
`-- src/
    |-- ReplicatedStorage/
    |-- ServerScriptService/
    `-- Workspace/
```

Edit a mapped script locally, then push that exact file once:

```powershell
node cli.js push game\src\ServerScriptService\Main.server.luau
```

A result with `verified: true` is complete. A result with `pending: true` is
also accepted and is waiting for a Studio Draft Mode commit. Do not retry a
pending push.

Read [Sync workflow](sync.md) before using source push in a production place.

## Give an AI verified context

Generate one compact briefing with Studio state, project memory, pending
changes, and GitHub repository activity:

```powershell
node cli.js ai-context
```

Coding agents should read [AI workflow](ai-usage.md) before changing a mapped
script. The guide defines the inspection, edit, push, and verification contract
for every model or agent host.

## Choose your next guide

| Goal | Continue with |
| --- | --- |
| Install the Windows app and Studio plugin | [Installation](installation.md) |
| Understand the desktop workspace | [Windows app](windows-app.md) |
| Pull, edit, and push scripts safely | [Sync workflow](sync.md) |
| Connect an AI coding agent | [AI workflow](ai-usage.md) |
| Chat with local LLMs and Memory Core | [Ollama workspace](ollama.md) |
| Read repository and Actions context | [GitHub context](github-context.md) |
| Use compact live Studio commands | [AXL command language](axl.md) |
| Integrate another local tool | [Local API reference](api.md) |

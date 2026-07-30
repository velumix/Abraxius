---
sidebar_label: First run
---

# First run

This walkthrough takes the Windows app from launch to a verified, read-only
Studio request. It does not modify the open place.

## Before you begin

You need:

- Roblox Studio open on the place you want to inspect
- **Allow HTTP Requests** enabled in **Game Settings > Security**
- the Abraxius companion installed
- the Abraxius development package registered

From the repository root:

```powershell
npm install
npm run rust:build
npm run install-plugin
npm run app:run
```

`app:run` registers and launches the WinUI package. Do not start a second Rust
daemon beside it; the app owns the local host.

## Check the three connections

Open **Home** and wait for the status cards:

| Card | Ready state | What it means |
|---|---|---|
| Server | Running | The app-owned Rust host answers on `127.0.0.1:13470` |
| Studio link | Connected | A compatible Studio MCP transport is available |
| Studio sync | Connected | Companion inspection and telemetry are available |

The companion can inspect Studio and export a full place without MCP. Targeted
pulls, `multi_edit`, and mapped script pushes still require MCP.

:::tip
Closing the window hides it. Abraxius and the Rust host continue running in the
notification area until you choose **Quit Abraxius**.
:::

## Run a harmless first request

1. Open **Commands**.
2. Wait for the green command-discovery message.
3. Choose **Inspect selection** under **What do you want to do?**
4. Select **Run inspection**.

The latest result contains the current Studio selection. No approval is needed
because this operation is read-only.

You can also verify from a terminal:

```powershell
node cli.js status
node cli.js plugin status
node cli.js plugin inspect Workspace
```

## Try the guarded workflow

When you are ready to test a mutation, use a uniquely named disposable script:

1. Open **Commands** and choose **Create a script**.
2. Set a path such as
   `ServerScriptService.AbraxiusReviewTest_20260729`.
3. Choose `ModuleScript` and enter a small source body.
4. Select **Add to Change Review**.
5. Open **Review**, inspect the target and exact arguments, then approve.
6. Delete only that exact test script through the same review flow.

Never use an existing production script to test connectivity.

## Where to go next

- [Workspace tour](app-workspaces.md)
- [Change Review](app-change-review.md)
- [Commands](app-commands.md)
- [Local AI](app-ai.md)

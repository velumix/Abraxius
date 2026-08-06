---
sidebar_position: 7
sidebar_label: GitHub context
---

# GitHub repository context

Abraxius can combine live Roblox Studio state with the delivery context around
the project. Its read-only GitHub provider discovers the current repository,
calls GitHub's versioned REST API through Octokit, and produces a compact
briefing for people or coding agents.

## Read the current repository

Run the command anywhere inside a GitHub checkout:

```powershell
node cli.js github-context
```

Abraxius walks up to the nearest `.git` directory and reads the `origin`
repository. Pass another repository explicitly when needed:

```powershell
node cli.js github-context velumix/Nerve
```

Use JSON when another tool needs structured data:

```powershell
node cli.js github-context --json
```

## What the briefing contains

The provider reads:

- repository name, description, visibility, license, stars, and forks
- default branch and its latest commit
- up to five recently updated open pull requests
- up to five recent GitHub Actions runs
- the latest published release when one exists
- the remaining REST API rate limit and reset time

The provider never mutates the repository. It does not create issues, merge
pull requests, dispatch workflows, or write releases.

## Authentication

Public repositories work without authentication at GitHub's anonymous rate
limit. Set one of these environment variables for private repository access or
higher limits:

```powershell
$env:GITHUB_TOKEN = "installation-or-user-token"
node cli.js github-context
```

`GH_TOKEN` is also supported. `GITHUB_TOKEN` takes precedence when both are
set.

Abraxius reads tokens only from the current process environment. Tokens are
never written to project memory, logs, JSON output, or Markdown briefings.

:::caution Use minimum permissions
Repository context is read-only. Give a token only the metadata, contents,
pull request, and Actions read permissions required for the repositories it
must inspect.
:::

For a user-facing integration, use a GitHub App installation token rather than
sharing a personal access token. The provider accepts either token form through
the same environment variable.

## AI context integration

`ai-context` automatically includes repository data when the active project has
a GitHub origin:

```powershell
node cli.js ai-context
node cli.js ai-context --json
```

GitHub access is best effort in the combined briefing. A network outage,
missing token, or insufficient repository permission never prevents Studio
context from loading.

Run `github-context` directly when GitHub failure should stop the command and
return an actionable error.

## Example output

```text
## GitHub Repository

- Repository: velumix/Abraxius
- Visibility: public
- Default branch: main
- Latest main commit: bc21403 Added GitHub repository context

### Open Pull Requests
- None.

### Recent Workflow Runs
- Added GitHub repository context: success on main
```

## Failure behavior

| Failure | Result |
| --- | --- |
| No GitHub origin | The direct command asks for an `owner/repository` argument |
| Repository not found | Returns the GitHub status and message |
| Bad or expired token | Returns an authentication error without printing the token |
| Missing Actions permission | Returns repository data and adds an Actions warning |
| No published release | Returns `latestRelease: null` without a warning |
| Rate limit exhausted | Returns GitHub's rate-limit error and reset information when available |

The provider uses GitHub REST API version `2026-03-10` and an eight-second
request timeout.

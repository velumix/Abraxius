const fs = require("fs");
const path = require("path");

const API_VERSION = "2026-03-10";

function parseGitHubRepository(value) {
  const input = String(value || "").trim();
  if (!input) return null;

  const url = input.match(
    /^(?:https?:\/\/github\.com\/|ssh:\/\/git@github\.com\/|git@github\.com:)([^/\s]+)\/([^/\s]+?)(?:\.git)?\/?$/,
  );
  if (url) return { owner: url[1], repo: url[2] };

  const shorthand = input.match(/^([^/@:\s]+)\/([^/\s]+?)(?:\.git)?$/);
  if (shorthand) {
    return { owner: shorthand[1], repo: shorthand[2] };
  }

  return null;
}

function findGitConfig(startPath) {
  let directory = path.resolve(startPath || process.cwd());
  const root = path.parse(directory).root;

  while (true) {
    const dotGit = path.join(directory, ".git");
    if (fs.existsSync(dotGit) && fs.statSync(dotGit).isDirectory()) {
      const config = path.join(dotGit, "config");
      if (fs.existsSync(config)) return config;
    }
    if (directory === root) return null;
    directory = path.dirname(directory);
  }
}

function repositoryFromProject(projectDir) {
  const configPath = findGitConfig(projectDir);
  if (!configPath) return null;

  const config = fs.readFileSync(configPath, "utf8");
  const origin = config.match(
    /\[remote\s+"origin"\][\s\S]*?\n\s*url\s*=\s*([^\r\n]+)/i,
  );
  return origin ? parseGitHubRepository(origin[1]) : null;
}

function normalizeError(error) {
  const status = error?.status || error?.response?.status || null;
  const message =
    error?.response?.data?.message ||
    error?.message ||
    "GitHub API request failed";
  return { status, message };
}

async function optionalRequest(octokit, route, parameters, warnings, label) {
  try {
    return await octokit.request(route, parameters);
  } catch (error) {
    if (error?.status === 404 && label === "latest release") return null;
    const detail = normalizeError(error);
    warnings.push(`${label}: ${detail.status || "error"} ${detail.message}`);
    return null;
  }
}

async function createOctokit(token) {
  const { Octokit } = await import("octokit");
  return new Octokit({
    ...(token ? { auth: token } : {}),
    request: { timeout: 8000 },
  });
}

async function fetchGitHubContext(options = {}) {
  const projectDir = path.resolve(options.projectDir || process.cwd());
  const repository =
    parseGitHubRepository(options.repository) ||
    repositoryFromProject(projectDir);
  if (!repository) {
    throw new Error(
      "Could not find a GitHub origin. Pass a repository as owner/name or run this command inside a GitHub checkout.",
    );
  }

  const token =
    options.token ||
    process.env.GITHUB_TOKEN ||
    process.env.GH_TOKEN ||
    null;
  const octokit = options.octokit || (await createOctokit(token));
  const headers = { "x-github-api-version": API_VERSION };
  const base = {
    owner: repository.owner,
    repo: repository.repo,
    headers,
  };

  let repositoryResponse;
  try {
    repositoryResponse = await octokit.request(
      "GET /repos/{owner}/{repo}",
      base,
    );
  } catch (error) {
    const detail = normalizeError(error);
    throw new Error(
      `GitHub repository request failed (${detail.status || "error"}): ${detail.message}`,
    );
  }

  const data = repositoryResponse.data;
  const warnings = [];
  const [pullsResponse, runsResponse, releaseResponse, commitResponse] =
    await Promise.all([
      optionalRequest(
        octokit,
        "GET /repos/{owner}/{repo}/pulls",
        { ...base, state: "open", sort: "updated", per_page: 5 },
        warnings,
        "open pull requests",
      ),
      optionalRequest(
        octokit,
        "GET /repos/{owner}/{repo}/actions/runs",
        { ...base, per_page: 5 },
        warnings,
        "workflow runs",
      ),
      optionalRequest(
        octokit,
        "GET /repos/{owner}/{repo}/releases/latest",
        base,
        warnings,
        "latest release",
      ),
      optionalRequest(
        octokit,
        "GET /repos/{owner}/{repo}/commits/{ref}",
        { ...base, ref: data.default_branch },
        warnings,
        "default branch commit",
      ),
    ]);

  const rateRemaining = repositoryResponse.headers?.["x-ratelimit-remaining"];
  const rateReset = repositoryResponse.headers?.["x-ratelimit-reset"];

  return {
    generatedAt: Date.now(),
    apiVersion: API_VERSION,
    authentication: token ? "token" : "anonymous",
    repository: {
      fullName: data.full_name,
      url: data.html_url,
      description: data.description || null,
      visibility: data.visibility || (data.private ? "private" : "public"),
      defaultBranch: data.default_branch,
      stars: data.stargazers_count,
      forks: data.forks_count,
      watchers: data.subscribers_count ?? data.watchers_count,
      openItems: data.open_issues_count,
      license: data.license?.spdx_id || null,
      archived: Boolean(data.archived),
      updatedAt: data.updated_at,
    },
    defaultBranchCommit: commitResponse
      ? {
          sha: commitResponse.data.sha,
          message: String(commitResponse.data.commit?.message || "")
            .split(/\r?\n/, 1)[0],
          author:
            commitResponse.data.author?.login ||
            commitResponse.data.commit?.author?.name ||
            null,
          url: commitResponse.data.html_url,
        }
      : null,
    openPullRequests: (pullsResponse?.data || []).map((pull) => ({
      number: pull.number,
      title: pull.title,
      author: pull.user?.login || null,
      draft: Boolean(pull.draft),
      updatedAt: pull.updated_at,
      url: pull.html_url,
    })),
    recentWorkflowRuns: (runsResponse?.data?.workflow_runs || []).map((run) => ({
      name: run.name,
      title: run.display_title,
      branch: run.head_branch,
      status: run.status,
      conclusion: run.conclusion,
      event: run.event,
      createdAt: run.created_at,
      url: run.html_url,
    })),
    latestRelease: releaseResponse
      ? {
          name: releaseResponse.data.name || releaseResponse.data.tag_name,
          tag: releaseResponse.data.tag_name,
          prerelease: Boolean(releaseResponse.data.prerelease),
          publishedAt: releaseResponse.data.published_at,
          url: releaseResponse.data.html_url,
        }
      : null,
    rateLimit: {
      remaining:
        rateRemaining === undefined ? null : Number(rateRemaining),
      resetsAt: rateReset
        ? new Date(Number(rateReset) * 1000).toISOString()
        : null,
    },
    warnings,
  };
}

function safeLine(value) {
  return String(value || "").replace(/\s+/g, " ").trim();
}

function toGitHubMarkdown(context) {
  const lines = ["## GitHub Repository", ""];
  const repository = context.repository;
  lines.push(`- Repository: [${repository.fullName}](${repository.url})`);
  lines.push(`- Description: ${repository.description || "none"}`);
  lines.push(`- Visibility: ${repository.visibility}`);
  lines.push(`- Default branch: ${repository.defaultBranch}`);
  lines.push(`- Stars: ${repository.stars}`);
  lines.push(`- Forks: ${repository.forks}`);
  lines.push(`- Open issues and pull requests: ${repository.openItems}`);
  lines.push(`- License: ${repository.license || "none"}`);
  if (context.defaultBranchCommit) {
    const commit = context.defaultBranchCommit;
    lines.push(
      `- Latest ${repository.defaultBranch} commit: [${commit.sha.slice(0, 7)}](${commit.url}) ${safeLine(commit.message)}`,
    );
  }
  if (context.latestRelease) {
    lines.push(
      `- Latest release: [${context.latestRelease.tag}](${context.latestRelease.url})`,
    );
  }
  lines.push("");

  lines.push("### Open Pull Requests");
  if (context.openPullRequests.length === 0) lines.push("- None.");
  for (const pull of context.openPullRequests) {
    const draft = pull.draft ? " draft" : "";
    lines.push(
      `- [#${pull.number}](${pull.url})${draft}: ${safeLine(pull.title)} by @${pull.author || "unknown"}`,
    );
  }
  lines.push("");

  lines.push("### Recent Workflow Runs");
  if (context.recentWorkflowRuns.length === 0) lines.push("- None available.");
  for (const run of context.recentWorkflowRuns) {
    const result = run.conclusion || run.status;
    lines.push(
      `- [${safeLine(run.title || run.name)}](${run.url}): ${result} on ${run.branch || "unknown branch"}`,
    );
  }

  if (context.warnings.length > 0) {
    lines.push("");
    lines.push("### GitHub API Warnings");
    for (const warning of context.warnings) lines.push(`- ${safeLine(warning)}`);
  }

  return `${lines.join("\n")}\n`;
}

module.exports = {
  API_VERSION,
  parseGitHubRepository,
  repositoryFromProject,
  fetchGitHubContext,
  toGitHubMarkdown,
};

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

const {
  API_VERSION,
  fetchGitHubContext,
  parseGitHubRepository,
  repositoryFromProject,
  toGitHubMarkdown,
} = require("../lib/github-context");

test("GitHub repository parser supports shorthand, HTTPS, and SSH remotes", () => {
  assert.deepEqual(parseGitHubRepository("velumix/Abraxius"), {
    owner: "velumix",
    repo: "Abraxius",
  });
  assert.deepEqual(
    parseGitHubRepository("https://github.com/velumix/Abraxius.git"),
    { owner: "velumix", repo: "Abraxius" },
  );
  assert.deepEqual(
    parseGitHubRepository("git@github.com:velumix/Abraxius.git"),
    { owner: "velumix", repo: "Abraxius" },
  );
  assert.equal(parseGitHubRepository("https://example.com/repository"), null);
});

test("GitHub repository discovery reads the origin from a project checkout", () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "abraxius-github-"));
  fs.mkdirSync(path.join(directory, ".git"));
  fs.writeFileSync(
    path.join(directory, ".git", "config"),
    '[remote "origin"]\n\turl = https://github.com/velumix/Abraxius.git\n',
    "utf8",
  );

  assert.deepEqual(repositoryFromProject(directory), {
    owner: "velumix",
    repo: "Abraxius",
  });
});

test("GitHub context collects repository, pull request, workflow, and commit data", async () => {
  const routes = [];
  const octokit = {
    async request(route, parameters) {
      routes.push({ route, parameters });
      if (route === "GET /repos/{owner}/{repo}") {
        return {
          headers: {
            "x-ratelimit-remaining": "4999",
            "x-ratelimit-reset": "1893456000",
          },
          data: {
            full_name: "velumix/Abraxius",
            html_url: "https://github.com/velumix/Abraxius",
            description: "Roblox Studio companion",
            visibility: "public",
            default_branch: "main",
            stargazers_count: 3,
            forks_count: 1,
            subscribers_count: 2,
            open_issues_count: 4,
            license: { spdx_id: "MIT" },
            archived: false,
            updated_at: "2026-07-26T20:00:00Z",
          },
        };
      }
      if (route === "GET /repos/{owner}/{repo}/pulls") {
        return {
          data: [{
            number: 7,
            title: "Add repository context",
            user: { login: "velumix" },
            draft: false,
            updated_at: "2026-07-26T21:00:00Z",
            html_url: "https://github.com/velumix/Abraxius/pull/7",
          }],
        };
      }
      if (route === "GET /repos/{owner}/{repo}/actions/runs") {
        return {
          data: {
            workflow_runs: [{
              name: "Tests",
              display_title: "Add repository context",
              head_branch: "agent/github-context",
              status: "completed",
              conclusion: "success",
              event: "pull_request",
              created_at: "2026-07-26T21:00:00Z",
              html_url: "https://github.com/velumix/Abraxius/actions/runs/1",
            }],
          },
        };
      }
      if (route === "GET /repos/{owner}/{repo}/releases/latest") {
        const error = new Error("Not Found");
        error.status = 404;
        throw error;
      }
      if (route === "GET /repos/{owner}/{repo}/commits/{ref}") {
        return {
          data: {
            sha: "1234567890abcdef",
            commit: {
              message: "Added repository context\n\nDetails",
              author: { name: "Velumix" },
            },
            author: { login: "velumix" },
            html_url: "https://github.com/velumix/Abraxius/commit/1234567",
          },
        };
      }
      throw new Error(`Unexpected route: ${route}`);
    },
  };

  const context = await fetchGitHubContext({
    repository: "velumix/Abraxius",
    token: "test-token",
    octokit,
  });

  assert.equal(context.apiVersion, API_VERSION);
  assert.equal(context.authentication, "token");
  assert.equal(context.repository.fullName, "velumix/Abraxius");
  assert.equal(context.defaultBranchCommit.sha, "1234567890abcdef");
  assert.equal(context.openPullRequests[0].number, 7);
  assert.equal(context.recentWorkflowRuns[0].conclusion, "success");
  assert.equal(context.latestRelease, null);
  assert.deepEqual(context.warnings, []);
  assert.equal(context.rateLimit.remaining, 4999);
  assert.doesNotMatch(JSON.stringify(context), /test-token/);
  assert.ok(
    routes.every(
      ({ parameters }) =>
        parameters.headers["x-github-api-version"] === API_VERSION,
    ),
  );

  const markdown = toGitHubMarkdown(context);
  assert.match(markdown, /GitHub Repository/);
  assert.match(markdown, /velumix\/Abraxius/);
  assert.match(markdown, /#7/);
  assert.match(markdown, /success on agent\/github-context/);
});

test("GitHub context reports a useful repository error", async () => {
  const octokit = {
    async request() {
      const error = new Error("Bad credentials");
      error.status = 401;
      throw error;
    },
  };

  await assert.rejects(
    fetchGitHubContext({
      repository: "velumix/Abraxius",
      octokit,
    }),
    /GitHub repository request failed \(401\): Bad credentials/,
  );
});

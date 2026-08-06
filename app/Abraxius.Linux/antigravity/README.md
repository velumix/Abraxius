# Abraxius Antigravity Bridge

A persistent Linux bridge between Abraxius and the interactive Antigravity CLI (`agy`). It solves the CLI behavior observed here: Antigravity must connect interactively before receiving a command, while `agy --print` can fail its immediate eligibility check.

## Features

- Keeps one interactive `agy` process connected through a pseudo-terminal.
- Waits for the Antigravity ready footer before sending prompts.
- Queues prompts so terminal input never interleaves.
- Exposes JavaScript callbacks through `EventEmitter`.
- Exposes a loopback HTTP API and Server-Sent Events (SSE).
- Automatically reconnects after unexpected CLI exits.
- Supports `SIGUSR1` to restart and `SIGUSR2` to interrupt.
- Requires explicit opt-in for `--dangerously-skip-permissions`.

## Requirements

- Linux
- Node.js 20 or newer
- `agy` available on `PATH`
- util-linux `script` available on `PATH` (used to allocate the PTY)

## Start for Abraxius

```sh
node bin/agy-bridge.js \
  --cwd /home/velumix/Desktop/Abraxius \
  --dangerously-skip-permissions
```

The process prints a random bearer token and starts its local API on `127.0.0.1:13472`. Set `ABRAXIUS_AGY_TOKEN` or pass `--token` to keep a stable token across restarts.

Permission bypass lets Antigravity modify the selected workspace without interactive approval. Omit the flag for read-only or manually approved use.

## HTTP API

### Health (no authentication)

```sh
curl http://127.0.0.1:13472/health
```

### Submit a nonblocking job (recommended)

This returns `202 Accepted` and a job ID immediately. Poll the returned ID or watch the SSE `job` event for completion:

```sh
curl \
  -H "Authorization: Bearer REPLACE_WITH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Inspect the repository and summarize its architecture."}' \
  http://127.0.0.1:13472/v1/jobs

curl \
  -H "Authorization: Bearer REPLACE_WITH_TOKEN" \
  http://127.0.0.1:13472/v1/jobs/JOB_ID
```

Use `GET /v1/jobs` to list retained jobs and `DELETE /v1/jobs/JOB_ID` to cancel queued or active work. The bridge retains the latest 100 job records in memory.

### Send a blocking prompt

The compatibility route stays open until the queued prompt completes or times out:

```sh
curl \
  -H "Authorization: Bearer REPLACE_WITH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Inspect the repository and summarize its architecture."}' \
  http://127.0.0.1:13472/v1/prompt
```

### Callback event stream

```sh
curl -N \
  -H "Authorization: Bearer REPLACE_WITH_TOKEN" \
  http://127.0.0.1:13472/v1/events
```

Events include `connected`, `state`, `request`, `output`, `response`, `request-error`, `exit`, `reconnecting` (carrying `attempt`, `delay`, `maxAttempts`, and `nextAttemptAt`), and `fault`.

Session reconnection uses a bounded exponential backoff policy configured via `reconnectPolicy` (`initialDelayMs`, `maxDelayMs`, `backoffFactor`, `maxAttempts`, `jitter`). Successful readiness resets attempt counters, and intentional session stops cancel active reconnect timers.

### Lifecycle routes

| Method | Route | Purpose |
|---|---|---|
| `POST` | `/v1/session/start` | Connect if stopped |
| `POST` | `/v1/session/restart` | Replace the current CLI session |
| `POST` | `/v1/session/interrupt` | Send Ctrl+C to the active request |
| `DELETE` | `/v1/session` | Stop the CLI session |

All lifecycle routes require the bearer token.

## JavaScript callbacks

```js
const { AgySession } = require("./src");

const session = new AgySession({
  cwd: "/home/velumix/Desktop/Abraxius",
  dangerouslySkipPermissions: true,
});

session.on("connected", (status) => console.log("connected", status.pid));
session.on("output", ({ text }) => process.stdout.write(text));
session.on("response", ({ id, text }) => console.log("response", id, text));
session.on("fault", ({ phase, error }) => console.error(phase, error));

await session.start();
const result = await session.send("Analyze the current changes.");
console.log(result.text);
await session.stop();
```

## Process signals

```sh
kill -USR1 BRIDGE_PID  # restart agy
kill -USR2 BRIDGE_PID  # interrupt the active request
kill -TERM BRIDGE_PID  # stop bridge and agy
```

Signals are intentionally not used for prompt data. HTTP/SSE or in-process callbacks provide framing, IDs, errors, and response content that Unix signals cannot carry.

See [`docs/architecture.md`](docs/architecture.md) for the design and security boundaries.

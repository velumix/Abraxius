# Architecture

```text
Abraxius / another local client
          |
          | HTTP request + SSE callbacks
          v
  Antigravity bridge (127.0.0.1:13472)
          |
          | serialized request queue
          v
  Persistent PTY (`script` -> `agy`)
          |
          v
  Antigravity service
```

The bridge starts one interactive `agy` process inside a pseudo-terminal and keeps it connected. Prompts are sent only after the CLI renders its ready footer. Each prompt asks Antigravity to assemble unique begin/end sentinels around its answer; because the exact sentinels do not occur in the echoed prompt, the bridge can identify the model response in TUI output.

## Communication choices

- **JavaScript callbacks:** `AgySession` extends `EventEmitter` and emits `connected`, `state`, `request`, `output`, `response`, `request-error`, `exit`, and `fault`.
- **HTTP:** local callers submit work with `POST /v1/prompt`.
- **SSE:** local callers subscribe to `/v1/events` for callback-style streaming events.
- **Signals:** `SIGUSR1` restarts the CLI and `SIGUSR2` interrupts the current request. Signals control lifecycle only because they cannot safely carry prompt or response data.

Only one prompt is active at a time. Additional prompts are queued to prevent terminal input from interleaving.

## Security boundaries

The server binds to `127.0.0.1` by default. All routes except `GET /health` require a bearer token. Permission bypass is disabled unless the process is explicitly started with `--dangerously-skip-permissions`.

This is intentionally separate from Abraxius's ports `13469`-`13471`; the default bridge port is `13472`.

## Current limitation

The built-in PTY transport uses the Linux `script` utility. A future Windows implementation should use ConPTY (for example through `node-pty`) behind the same `spawnProcess` interface.

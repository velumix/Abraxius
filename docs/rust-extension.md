# Rust Extension

Abraxius includes a Rust crate at `rust/abraxius-rs` with two binaries:

- `abraxius-rs`: a native control CLI for the Abraxius API and plugin workflows.
- `abraxius-daemon`: a Rust daemon that serves the MCP WebSocket bridge, HTTP API, and Studio companion plugin channel.

## Build

```bash
npm run rust:check
npm run rust:build
```

Or use Cargo directly:

```bash
cargo build --manifest-path rust/abraxius-rs/Cargo.toml
```

## Run

```bash
npm run rust:run -- status
npm run rust:run -- ai-context
npm run rust:run -- plugin status
npm run rust:run -- pending
```

Run the Rust daemon:

```bash
npm run rust:daemon
```

It listens on the same ports as the Node daemon:

| Port | Purpose |
|---|---|
| `13469` | MCP WebSocket bridge at `/studio` |
| `13470` | Main HTTP API |
| `13471` | Studio companion plugin long-poll channel |

After building, the binary is available under Cargo's target directory:

```bash
rust/abraxius-rs/target/debug/abraxius-rs.exe
```

## Commands

| Command | Description |
|---|---|
| `status` | Read daemon health from `localhost:13470` |
| `start-node` | Start the existing Node daemon |
| `stop` | Ask the daemon to shut down |
| `tools` | List MCP tools |
| `state` | Read Studio state |
| `call <tool> [json]` | Call an MCP tool |
| `execute <luau>` | Execute Luau through the daemon |
| `ai-context [--json]` | Print the AI context briefing |
| `remember <text>` | Add pinned project memory |
| `memory [clear [id]]` | Read or clear pinned memory |
| `pending [verify|clear]` | Inspect or verify pending Studio pushes |
| `plugin ...` | Inspect or command the Studio companion plugin |
| `install-plugin` | Install the companion as `AbraxiusCompanion.lua` |

## Current role

The Rust daemon now implements the core bridge shape directly: MCP initialization, JSON-RPC tool calls, health/tools/state/execute endpoints, AI context memory, pending push tracking, and companion plugin command/event polling.

The Node daemon remains available as the mature fallback while the Rust daemon reaches full CLI parity for high-level sync helpers such as pull and push.

# Abraxius Memory Core

Abraxius Memory Core is a local-first, durable hive mind memory system designed for Abraxius. It enables multiple AI coding agents, LLM providers, and MCP clients (Antigravity, Zed, Claude, Gemini, Ollama) to share the same persistent memory across sessions and projects without relying on paid cloud services.

---

## 1. Architecture Overview

Abraxius Memory Core consists of eight decoupled subsystems managed by the central `MemoryOrchestrator`:

1. **Memory Store (`lib/memory/store.js`)**: Crash-resilient, thread-safe, atomic file-backed JSON/SQLite store with supersession tracking and session retention cleanup.
2. **Embedding Provider (`lib/memory/embeddings.js`)**: Abstract embedding engine with configurable Ollama embeddings (`nomic-embed-text`) and automatic TF-IDF/keyword fallback when Ollama is offline.
3. **Retrieval & Ranking Engine (`lib/memory/retrieval.js`)**: Pre-request hybrid retrieval combining semantic similarity, keyword overlap, exponential time decay, confidence, verification status, and access frequency.
4. **Extraction Engine (`lib/memory/extraction.js`)**: Post-task LLM memory extraction with JSON schema validation, secret filter, deduplication, and human Review Queue.
5. **Streamable HTTP MCP Server (`lib/memory/mcp-http-server.js`)**: Local HTTP/SSE server running on `127.0.0.1:8765/mcp` exposing 12 MCP memory tools with LAN authorization security.
6. **Document / Obsidian Indexer (`lib/memory/indexer.js`)**: Opt-in directory scanner for Obsidian vaults and Markdown folders with allowlist enforcement, ignore rules, and hash-based incremental indexing.
7. **Abraxius Host Integration (`server.js` & `lib/ai-context.js`)**: Integrates directly into the prompt boundary to inject `<abraxius_memory>` context blocks into provider requests.
8. **Memory UI (`app/Abraxius.Linux/`)**: Linux Electron application dashboard for searching, reviewing, editing, correcting, and configuring memories.

---

## 2. Record Schema & Scopes

### Scopes
- `global`: User preferences and cross-project knowledge.
- `project`: Project-specific facts, architecture, and requirements (isolated by `projectId`).
- `agent`: Agent-specific workflows and task history (isolated by `agentId`).
- `session`: Short-lived session notes (auto-expiring based on `expiresAt`).
- `private`: Sensitive local developer notes (never sent to cloud LLM models).

### Memory Types
`preference`, `project_fact`, `requirement`, `technical_decision`, `known_issue`, `failed_attempt`, `successful_fix`, `procedure`, `person`, `organization`, `pending_task`, `summary`, `custom`.

### Record Fields
- `id`: UUID v4
- `scope`: `global` | `project` | `agent` | `session` | `private`
- `projectId`: optional string
- `agentId`: optional string
- `sessionId`: optional string
- `type`: Memory type string
- `content`: Full detailed memory text
- `summary`: Short 1-line summary
- `tags`: String array of tags
- `sourceType`: `user` | `agent` | `llm_extraction` | `document_index` | `mcp`
- `sourceReference`: File path or URI reference
- `confidence`: Number between `0.0` and `1.0`
- `verificationStatus`: `proposed` | `verified` | `disputed` | `superseded`
- `sensitivity`: `normal` | `private` | `secret-rejected`
- `createdAt`, `updatedAt`, `accessedAt`: Epoch timestamps
- `accessCount`: Usage counter
- `expiresAt`: Optional expiration timestamp
- `supersedesId`: Link to previous record version (for conflict history)

---

## 3. Secret Detection & Security Rules

All memory inputs are passed through strict pattern matching before storage. Records containing any of the following are **immediately rejected**:
- API Keys (`sk-...`, `ghp_...`, `glpat-...`, AWS access keys)
- Bearer Tokens and JWTs
- Passwords and private key blocks (`-----BEGIN PRIVATE KEY-----`)
- Database Connection Strings (`postgres://...`, `mongodb://...`)
- Authentication Cookies and Secret Environment Variables

> **Security Guarantee**: Sensitive credential values are NEVER logged or saved to disk.

---

## 4. Hybrid Ranking Algorithm

Retrieved memories are scored and ranked using the following formula:

$$\text{FinalScore} = 0.50 \cdot \text{Similarity} + 0.15 \cdot \text{Recency} + 0.15 \cdot \text{Confidence} + 0.10 \cdot \text{Verification} + 0.10 \cdot \text{AccessScore}$$

- **Similarity**: $0.65 \cdot \text{CosineSimilarity} + 0.35 \cdot \text{KeywordScore}$ (or $1.0 \cdot \text{KeywordScore}$ if embeddings are disabled).
- **Recency**: $\exp(-\text{ageInDays} / 30)$
- **Prompt Injection Guard**: Memory facts are rendered inside an `<abraxius_memory>` block with strict system notices instructing the LLM to treat memory data as untrusted reference material, not system commands.

---

## 5. MCP Server Configuration & Tools

The local MCP Memory Server runs on `http://127.0.0.1:8765/mcp` by default.

### Available MCP Tools
1. `memory_search`: Search memories using hybrid ranking.
2. `memory_add`: Add a durable memory.
3. `memory_get`: Retrieve record by UUID.
4. `memory_update`: Update memory record fields.
5. `memory_correct`: Correct a memory (supersedes original, preserves history).
6. `memory_forget`: Remove record (**Requires `confirm: true`**).
7. `memory_list_recent`: List recent active memories.
8. `memory_list_decisions`: List architectural decisions.
9. `memory_list_failed_attempts`: List recorded failures & bug analysis.
10. `memory_get_project_brief`: Retrieve project summary brief.
11. `memory_index_document`: Index an approved Markdown document.
12. `memory_health`: Report system health and record counts.

---

## 6. Client MCP Configuration Examples

### Antigravity (`.mcp.json`)
```json
{
  "mcpServers": {
    "abraxius-memory": {
      "command": "node",
      "args": ["cli.js", "stdio"]
    }
  }
}
```

### Zed (`settings.json`)
```json
{
  "context_servers": {
    "abraxius-memory": {
      "settings": {
        "endpoint": "http://127.0.0.1:8765/mcp"
      }
    }
  }
}
```

### Claude Desktop (`claude_desktop_config.json`)
```json
{
  "mcpServers": {
    "abraxius-memory": {
      "command": "node",
      "args": ["/home/user/Desktop/Abraxius/cli.js", "stdio"]
    }
  }
}
```

---

## 7. Ollama Embedding Setup

1. Install and launch Ollama:
   ```bash
   ollama serve
   ```
2. Pull the default embedding model:
   ```bash
   ollama pull nomic-embed-text
   ```
3. Abraxius Memory Core automatically connects to `http://127.0.0.1:11434`. If Ollama is offline, Memory Core automatically uses full-text keyword search without breaking.

---

## 8. Obsidian & Markdown Indexing

To index an Obsidian vault or Markdown folder:
1. In Abraxius Linux UI, open **Memory Core > Vault Indexer**.
2. Enter the absolute directory path (e.g. `/home/user/Documents/ObsidianVault`).
3. Click **Approve & Index Directory**.
4. Memory Core will scan Markdown files, ignore `.git`, binaries, and secrets, chunk text by headings, and store facts with source references (`filepath#heading`).

---

## 9. Maintenance: Backup & Reset

### Backup
Copy the `.abraxius` directory:
```bash
cp -r .abraxius .abraxius_backup_$(date +%F)
```

### Session-Only Reset
To clear expired or active session memories without touching durable project facts:
```bash
node -e "const { MemoryStore } = require('./lib/memory'); new MemoryStore().cleanExpiredSessions();"
```

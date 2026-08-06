# Local Ollama Workspace in Abraxius

Abraxius features a first-class **Ollama Workspace tab** alongside the persistent Antigravity CLI, allowing you to chat directly with local Large Language Models (LLMs) inside the desktop application while leveraging Abraxius Memory Core for context retrieval.

---

## 1. Quick Start & Setup

### Step 1: Install Ollama
Install Ollama on Linux using the official setup script or package manager:
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### Step 2: Launch Ollama Daemon
Start the local Ollama service:
```bash
ollama serve
```
By default, Ollama listens on `http://127.0.0.1:11434`.

### Step 3: Pull Models
Download your preferred models:
```bash
# Recommended agentic coding model
ollama pull qwen3-coder:30b
# Lighter Apache-2.0 alternative
ollama pull devstral-small-2

# Recommended embedding model for Memory Core
ollama pull nomic-embed-text
```

---

## 2. Using the Ollama Workspace Tab

1. Open **Abraxius** and click the **Ollama** tab in the sidebar navigation.
2. Verify the status indicator shows **Online** (`http://127.0.0.1:11434`).
3. Select your model from the model selector dropdown (click **Refresh** if you recently downloaded a new model).
4. Enter your prompt in the prompt composer.
5. Press **Ctrl + Enter** or click **Send**.
6. Watch the response stream incrementally in the clean chat output panel.

### Additional Controls
* **Stop Generation**: Click **Stop** at any time to cancel active text generation without freezing the interface.
* **Clear Chat**: Click **Clear** in the action bar to reset the chat conversation container.
* **Copy Response**: Click **Copy** on any message bubble to copy its raw text content to your clipboard.
* **Settings Menu**: Click the gear icon in the top action bar to adjust the endpoint URL, temperature, context length (`num_ctx`), and Memory Core context toggles.

---

## 3. Interactive PTY Terminal & View Modes

The Ollama workspace tab features a live, PTY-backed interactive Ollama session (`OllamaSession`), analogous to the Antigravity tab:

1. **PTY Session Lifecycle**:
   - Spawns a real pseudo-terminal (`util-linux` `script` on Linux) bounded strictly to the `ollama` CLI (e.g. `ollama run qwen3.5:9b-q4_K_M`).
   - Supports live interactive input, ANSI streaming, and stdout/stderr output using xterm.js (`ollamaTerminal`).
   - Dedicated controls: **Start / Restart PTY**, **Interrupt PTY** (SIGINT), and **Stop PTY**.
2. **View Modes**:
   - **Chat Mode**: Displays clean structured chat bubbles powered by Ollama API with Memory Core context.
   - **Terminal Mode**: Displays live full-screen interactive PTY terminal output.
   - **Split Mode**: Side-by-side view showing structured API chat alongside the live interactive PTY terminal.

---

## 4. Abraxius Memory Core & Privacy Policy

When sending prompts in the Ollama workspace tab, Abraxius automatically integrates with **Abraxius Memory Core**:

1. **Context Retrieval**: Before sending your prompt to the local model, Abraxius queries the local memory store for relevant project facts, architectural decisions, and session notes.
2. **Untrusted Memory Sandbox**: Retrieved memories are wrapped inside a clearly labeled `<abraxius_memory>` block to prevent prompt injection.
3. **Privacy Policy Rules**:
   * **Local Models**: Private developer notes (`scope: private`) are accessible to local Ollama models running on loopback (`127.0.0.1`).
   * **Remote/Cloud Models**: If a model is flagged as remote (`isRemote: true`), private memories are **strictly excluded** before sending.
   * **Privacy Indicator**: Each assistant response displays a privacy badge summarizing memory recall status.

---

## 5. Anti-Doom-Loop Protection

The Ollama workspace includes an automated generation loop guard (`AiLoopGuard`):
* If a model enters a repetitive output loop (e.g. repeating a >60-character span 4 consecutive times), generation is automatically stopped.
* The partial output is preserved, and a recovery message is appended (`[Generation stopped: Repetitive output loop detected. Partial response preserved.]`).

---

## 6. Ollama Agent Loop

The Ollama workspace now defaults to **Agent loop: inspect, apply, verify**. Ollama is the interpreter and Abraxius is the tool/runtime layer. It can request compact `ABRAXIUS_TOOL` calls, receive bounded results, reassess, and repeat for at most five iterations. It must finish with `STATUS: SUCCESS` backed by a concrete check, or `STATUS: MISSING` with the exact missing evidence or permission.

Mutating calls remain approval-gated by default. Enable **Allow agent edits** only when you want automatic `multi_edit` or `execute_luau` calls. Internet research is separately permissioned and labeled untrusted reference context.

Ollama currently lists Qwen3-Coder 30B as a long-context agentic coding model, while Devstral Small 2 is a lighter Apache-2.0 tool-using coding option. Choose the largest model your hardware can run reliably.

## 7. Architecture & IPC Integration

* **Ollama PTY Session (`app/Abraxius.Linux/ollama/ollama-session.js`)**: Manages bounded interactive PTY processes (`OllamaSession`), command resolution (`resolveOllamaCommand`), and stdin/stdout relaying.
* **Agent loop (`lib/ollama-agent.js`)**: Parses nested tool markers, bounds iterations/results, and enforces mutation policy.
* **Main Process (`app/Abraxius.Linux/main.js`)**: Exposes IPC calls (`ollama-status`, `ollama-models`, `ollama-chat`, `ollama-agent`, `ollama-cancel`, `ollama-settings-get`, `ollama-settings-save`, `ollama-pty-status`, `ollama-pty-start`, `ollama-pty-restart`, `ollama-pty-stop`, `ollama-pty-interrupt`, `ollama-pty-write`).
* **Preload (`app/Abraxius.Linux/preload.js`)**: Exposes frozen `window.abraxius.ollama` bridge for main world renderer.
* **Core Library (`lib/ollama.js`)**: Exports `OllamaSession`, `resolveOllamaCommand`, `OllamaClient`, `AiLoopGuard`, `preparePromptWithMemory`, and settings persistence logic.

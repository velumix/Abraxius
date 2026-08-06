const test = require("node:test");
const assert = require("node:assert");
const EventEmitter = require("events");
const { OllamaSession, resolveOllamaCommand } = require("../app/Abraxius.Linux/ollama/ollama-session");

test("resolveOllamaCommand finds binary in user-local or system path", () => {
  const resolved = resolveOllamaCommand();
  assert.ok(typeof resolved === "string");
  assert.ok(resolved.includes("ollama"));
});

test("OllamaSession lifecycle: start, status, writeInput, interrupt, restart, stop", async () => {
  class FakeProcess extends EventEmitter {
    constructor() {
      super();
      this.pid = 99999;
      this.stdin = {
        written: [],
        write(data) {
          this.written.push(data);
          return true;
        },
      };
      this.stdout = new EventEmitter();
      this.stderr = new EventEmitter();
    }

    kill(signal) {
      this.emit("exit", 0, signal);
    }
  }

  let spawnedProcess = null;
  const mockSpawn = (options) => {
    spawnedProcess = new FakeProcess();
    spawnedProcess.options = options;
    return spawnedProcess;
  };

  const session = new OllamaSession({
    model: "qwen3.5:9b-q4_K_M",
    spawnProcess: mockSpawn,
  });

  assert.strictEqual(session.status().state, "stopped");

  const startStatus = await session.start();
  assert.strictEqual(startStatus.state, "ready");
  assert.strictEqual(startStatus.pid, 99999);
  assert.strictEqual(startStatus.model, "qwen3.5:9b-q4_K_M");
  assert.deepStrictEqual(startStatus.args, ["run", "qwen3.5:9b-q4_K_M"]);

  // Test output event relaying
  let receivedOutput = null;
  session.on("output", (payload) => {
    receivedOutput = payload;
  });

  spawnedProcess.stdout.emit("data", Buffer.from("Hello from Ollama PTY"));
  assert.ok(receivedOutput);
  assert.strictEqual(receivedOutput.data, "Hello from Ollama PTY");

  // Test interactive writeInput
  const writeRes = session.writeInput("/show info\n");
  assert.strictEqual(writeRes.written, true);
  assert.deepStrictEqual(spawnedProcess.stdin.written, ["/show info\n"]);

  // Test interrupt
  const interrupted = session.interrupt();
  assert.strictEqual(interrupted, true);

  // Test restart
  const restartStatus = await session.restart({ model: "qwen3.5:9b-q4_K_M" });
  assert.strictEqual(restartStatus.state, "ready");

  // Test stop
  const stopStatus = await session.stop();
  assert.strictEqual(stopStatus.state, "stopped");
});

test("writeInput rejects input when session is stopped", () => {
  const session = new OllamaSession();
  const res = session.writeInput("test");
  assert.strictEqual(res.written, false);
  assert.strictEqual(res.reason, "session_stopped");
});

test("OllamaSession bounds execution strictly to ollama binary", () => {
  const session = new OllamaSession({ command: "/home/velumix/.local/bin/ollama", model: "qwen3.5:9b-q4_K_M" });
  const status = session.status();
  assert.strictEqual(status.command, "/home/velumix/.local/bin/ollama");
  assert.deepStrictEqual(status.args, ["run", "qwen3.5:9b-q4_K_M"]);
});

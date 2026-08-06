"use strict";

const { app, safeStorage } = require("electron");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { NvidiaNimClient } = require("../lib/nvidia-nim");

const prompt = process.argv.slice(2).join(" ").trim();
const userData = path.join(os.homedir(), ".config", "Abraxius");

async function main() {
  if (!prompt) throw new Error("A prompt is required.");
  app.setName("Abraxius");
  app.setPath("userData", userData);
  await app.whenReady();
  const keyPath = path.join(app.getPath("userData"), "linux", "nvidia-nim-api-key.enc");
  if (!safeStorage.isEncryptionAvailable()) throw new Error("Electron safeStorage is unavailable.");
  if (!fs.existsSync(keyPath)) throw new Error("No NVIDIA NIM key is saved in Abraxius. Add it in the NVIDIA NIM tab first.");
  const encoded = fs.readFileSync(keyPath, "utf8").trim();
  const apiKey = safeStorage.decryptString(Buffer.from(encoded, "base64"));
  const client = new NvidiaNimClient({ apiKey });
  await client.streamChat({
    messages: [{ role: "user", content: prompt }],
    onReasoning: (chunk) => process.stdout.write(chunk),
    onChunk: (chunk) => process.stdout.write(chunk),
  });
  process.stdout.write("\n");
  app.quit();
}

main().catch((error) => {
  process.stderr.write(`${error.message}\n`);
  app.quit();
  process.exitCode = 1;
});

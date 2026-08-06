"use strict";
const { app, safeStorage } = require("electron");
const fs = require("fs");
const { OpenRouterClient } = require("../lib/openrouter");
app.setName("Abraxius");
app.whenReady().then(async () => {
  try {
    const key = safeStorage.decryptString(Buffer.from(fs.readFileSync("/home/velumix/.config/Abraxius/linux/openrouter-api-key.enc", "utf8").trim(), "base64"));
    let answer = "";
    await new OpenRouterClient({ apiKey: key }).streamChat({
      model: "inclusionai/ling-3.0-flash:free",
      messages: [{ role: "user", content: "Design a practical old-school developer UI treatment for an OpenRouter tab inside Abraxius. Think classic IDEs, DOS terminals, Win95/98 utility panels, and early Unix tools: dense information, clear borders, keyboard-first interaction, restrained colors, readable monospace status text. Give 5 concrete HTML/CSS/vanilla-JS changes that improve usability without making it ugly or replacing the existing dark theme." }],
      onChunk: (chunk) => { answer += chunk; },
    });
    process.stdout.write(answer + "\n");
    app.quit();
  } catch (error) { process.stderr.write(error.message + "\n"); app.exit(1); }
});

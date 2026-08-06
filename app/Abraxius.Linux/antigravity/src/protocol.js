"use strict";

const crypto = require("crypto");

function createEnvelope(prompt, id = crypto.randomUUID()) {
  if (typeof prompt !== "string" || !prompt.trim()) {
    throw new TypeError("prompt must be a non-empty string");
  }
  if (prompt.length > 200_000) throw new RangeError("prompt exceeds 200,000 characters");
  if (prompt.includes("\0")) throw new TypeError("prompt cannot contain NUL bytes");

  const begin = `<ABRAXIUS_BEGIN_${id}>`;
  const done = `<ABRAXIUS_DONE_${id}>`;
  const framedPrompt = [
    prompt.trim(),
    "",
    "Protocol instructions:",
    `1. Begin your response with one plain line made by concatenating these fragments without spaces or Markdown: \"<ABRAXIUS_\", \"BEGIN_\", \"${id}\", \">\".`,
    "2. Perform the requested task and report its result.",
    `3. Finish with one plain line made by concatenating these fragments without spaces or Markdown: \"<ABRAXIUS_\", \"DONE_\", \"${id}\", \">\".`,
  ].join("\n");

  return { id, prompt: framedPrompt, begin, done };
}

module.exports = { createEnvelope };

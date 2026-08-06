"use strict";

function stripAnsi(value) {
  return String(value)
    .replace(/\x1B\][^\x07]*(?:\x07|\x1B\\)/g, "")
    .replace(/\x1B(?:\[[0-?]*[ -/]*[@-~]|[@-_])/g, "")
    .replace(/\u009B[0-?]*[ -/]*[@-~]/g, "");
}

function cleanTranscript(value) {
  const lines = stripAnsi(value)
    .replace(/\r\n?/g, "\n")
    .split("\n")
    .map((line) => line.replace(/[ \t]+$/g, ""));

  const cleaned = [];
  for (const line of lines) {
    if (/^[─━═-]{12,}$/.test(line.trim())) continue;
    if (/^\? for shortcuts\b/.test(line.trim())) continue;
    if (/^Gemini\s+\S+.*(?:low|medium|high)$/i.test(line.trim())) continue;
    cleaned.push(line);
  }

  return cleaned.join("\n").replace(/\n{3,}/g, "\n\n").trim();
}

module.exports = { cleanTranscript, stripAnsi };

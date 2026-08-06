"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { cleanTranscript, stripAnsi } = require("../src/terminal-text");

test("stripAnsi removes CSI color sequences", () => {
  assert.equal(stripAnsi("\x1b[31mREADY\x1b[0m"), "READY");
});

test("cleanTranscript removes TUI chrome without deleting duplicate response lines", () => {
  const input = [
    "──────────────",
    "Answer",
    "Answer",
    "? for shortcuts",
    "",
  ].join("\r\n");
  assert.equal(cleanTranscript(input), "Answer\nAnswer");
});

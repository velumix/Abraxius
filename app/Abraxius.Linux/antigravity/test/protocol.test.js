"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createEnvelope } = require("../src/protocol");

const ID = "12345678-1234-1234-1234-123456789abc";

test("createEnvelope keeps exact response sentinels out of the echoed prompt", () => {
  const envelope = createEnvelope("Review the repository", ID);
  assert.equal(envelope.begin, `<ABRAXIUS_BEGIN_${ID}>`);
  assert.equal(envelope.done, `<ABRAXIUS_DONE_${ID}>`);
  assert.equal(envelope.prompt.includes(envelope.begin), false);
  assert.equal(envelope.prompt.includes(envelope.done), false);
  assert.match(envelope.prompt, /Review the repository/);
});

test("createEnvelope rejects unsafe or empty prompts", () => {
  assert.throws(() => createEnvelope(""), /non-empty/);
  assert.throws(() => createEnvelope("bad\0prompt"), /NUL/);
});

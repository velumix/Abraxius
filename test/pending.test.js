const test = require("node:test");
const assert = require("node:assert/strict");
const { PendingPushes, hashSource } = require("../lib/pending");

test("pending hashes treat Studio LF and Windows CRLF as identical", () => {
  const localSource = "local value = 1\r\nreturn value\r\n";
  const studioSource = "local value = 1\nreturn value\n";
  assert.equal(hashSource(localSource), hashSource(studioSource));

  const pending = new PendingPushes();
  pending.recordPush("game.ServerScriptService.Main", localSource);
  const verified = pending.verify("game.ServerScriptService.Main", studioSource);
  assert.equal(verified.stale, false);
  assert.equal(verified.status, "live");
});

test("committed source mismatch remains pending while a Draft Mode edit is uncommitted", () => {
  const pending = new PendingPushes();
  pending.recordPush("game.ServerScriptService.Main", "return 'draft'");
  const verified = pending.verify("game.ServerScriptService.Main", "return 'committed'");
  assert.equal(verified.stale, null);
  assert.equal(verified.status, "pending");
});

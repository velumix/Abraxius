---
sidebar_label: Change Review
---

# Change Review

Change Review is the app's mutation boundary. Nothing on the page runs
automatically, and every apply requires a final confirmation.

## What appears in Review

Two sources feed the staged list:

| Source | How it gets there |
|---|---|
| Dirty Code buffer | Edit a pulled script and select **Review change** |
| Queued command | Build an operation in Commands and select **Add to Change Review** |

Dismissing an item hides it from the current review without deleting the editor
buffer or queued command. Refreshing restores dismissed items.

## Review an editor change

1. Select the dirty script.
2. Abraxius sends a read-only `write_source` dry run with the pulled source
   hash.
3. Inspect the changed line blocks in **Exact preview**.
4. Confirm the target, risk, explanation, and preflight receipt.
5. Select **Apply selected** and confirm.

Apply reads the current source, writes with optimistic hash protection, reads
the result back, and only reports success when the approved source matches.

## Review a command

1. Select the queued operation.
2. Inspect its resolved target and formatted JSON arguments.
3. Confirm the risk label and intended effect.
4. Select **Apply selected** and confirm.

After success the operation is removed from the Commands approval queue and a
redacted outcome is added to command history.

## Risk labels

Risk is a deterministic warning aid, not a proof of safety.

| Level | Typical examples |
|---|---|
| Low | Read-only inspection and small non-server editor changes |
| Medium | Instance mutations, server scripts, or larger source buffers |
| High | Script creation/replacement, exact multi-edit, deletion, Luau execution, or sensitive services |

High-risk operations are not blocked, but their target and payload should
receive extra scrutiny.

## Roll back the last source apply

After a verified editor apply, **Rollback last source apply** becomes available.
Abraxius retains:

- the exact previous source
- the path
- the hash of the applied result

Rollback uses that hash as a conflict guard and verifies the restored source by
read-back. It only covers the most recent verified editor source apply; it is
not a general undo stack for arbitrary Commands operations.

:::warning
If Studio changed the script after the apply, the expected hash prevents a
blind rollback. Inspect the newer source instead of forcing an overwrite.
:::

## Draft Mode

Mapped CLI pushes can report `pending: true` while Draft Mode hides an
uncommitted edit. Treat that as accepted and do not retry. The app review flow
and the CLI pending workflow are related safety surfaces but have different
completion receipts. See [Sync workflow](sync.md).

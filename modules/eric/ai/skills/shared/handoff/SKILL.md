---
name: handoff
description: Compact the whole conversation, or one thread of it, into a handoff document for a different agent (claude, codex, pi, or a fresh session) to pick up
argument-hint: "[empty for the whole conversation | the thread or task to hand off]"
disable-model-invocation: true
---

Write a handoff document so a fresh agent can continue the work.

Scope:

- Empty: the whole conversation, with every thread that is still open.
- A thread or task named: only that slice. Include its goal, its decisions and rejections, its open items, and the shared facts it depends on (paths, settings, constraints) even when they came up elsewhere in the session. Leave out the other threads, and name them in one line under "Not included" so the reader knows they exist.

Save it to `/tmp/handoff-<YYYYMMDD-HHMM>-<short-slug>.md`, not `$TMPDIR` or a session scratchpad.

The reader shares the filesystem but none of the history: name absolute paths, spell out decisions already made and rejected, and state what is still open.

Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

Finish by printing the absolute path on its own line, so it can be pasted straight into the receiving agent.

---
name: handoff
description: Compact the current conversation into a handoff document for a different agent (codex, copilot, a fresh CLI) to pick up.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work.

Save it to `/tmp/handoff-<YYYYMMDD-HHMM>-<short-slug>.md`, in preference to `$TMPDIR` or any session scratchpad directory the environment nominates.

The reader shares the filesystem but none of the history: name absolute paths, spell out decisions already made and rejected, and state what is still open.

Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.

Finish by printing the absolute path on its own line, so it can be pasted straight into the receiving agent.

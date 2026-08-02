---
name: consulting-codex
description: Use when you want an independent second opinion from a different model on code, a plan, or a review, or when you need to follow up on an answer codex already gave.
---

# Consulting codex

Codex is a **different model**, so its value is disagreement. Ask it to judge, not to fetch. Never reconcile away its verdict when reporting back -- quote it, then say where you disagree.

Pin `-m gpt-5.6-sol -c model_reasoning_effort="high"` on every call. `~/.codex/config.toml` sets the same values today, so pinning is what stops a later edit there from silently swapping the model mid-review.

Runs take minutes. Launch with `run_in_background: true` and wait for the completion notification; never poll with `pgrep -f`, whose pattern matches the polling loop itself and never exits. The answer is whatever lands in `-o`; write it to the scratchpad and read it from there.

## First turn

```bash
codex exec --sandbox read-only -m gpt-5.6-sol -c model_reasoning_effort="high" \
  -C /path/to/repo --json -o <scratchpad>/codex-1.md "<prompt>" < /dev/null
```

- `-o` writes **only** the final message. Bare `codex exec` buries it in a huge trace.
- `--json` makes the first line `{"type":"thread.started","thread_id":"<uuid>"}`. **Capture that id** if a follow-up is at all likely; without it you are limited to `--last`.
- `-C <repo>` is required, else it fails with `Not inside a trusted directory`.
- `< /dev/null` stops codex blocking on stdin when stdin is not a TTY.

## Follow-up turns

`resume` carries full conversation context but takes a **different flag set**.

```bash
codex exec resume -m gpt-5.6-sol -c model_reasoning_effort="high" \
  -c sandbox_mode="read-only" -o <scratchpad>/codex-2.md <thread_id> "<prompt>" < /dev/null
```

- No `-C` and no `--sandbox`. Set the working directory yourself, and reach the sandbox through `-c sandbox_mode="read-only"`.
- Options come **before** `<thread_id>`. `resume <id> -o file` fails with a bare usage error.
- `--last` replaces `<thread_id>` to resume the most recent session.

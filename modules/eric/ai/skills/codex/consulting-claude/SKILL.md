---
name: consulting-claude
description: Use when you want an independent second opinion from Claude Opus 4.8 on code, a plan, or a review, or when you need to follow up on an answer Codex already gave.
---

# Consulting Claude

Claude is a different model, so its value is disagreement. Ask it to judge,
not merely to fetch information. Preserve its verdict when reporting back,
then say explicitly where you agree or disagree.

Pin `--model claude-opus-4-8` on every call. Do not rely on Claude's user
configuration to choose the model; a later config change must not silently
change the reviewer.

Run Claude from the repository being reviewed. Use non-interactive print mode,
plan permissions, and no session persistence so a consultation cannot edit the
checkout or leave a resumable session behind. Save the response to a
scratchpad and read that file after the command completes. These calls can take
minutes; run them in the background and wait for completion rather than polling
with `pgrep -f`.

## First turn

```bash
mkdir -p <scratchpad>
cd /path/to/repo && claude --print \
  --model claude-opus-4-8 \
  --permission-mode plan \
  --output-format text \
  --no-session-persistence \
  "<prompt>" > <scratchpad>/claude-1.md < /dev/null
```

- `--print` makes the call non-interactive and returns the final answer.
- `--permission-mode plan` keeps the consultation read-only while allowing
  Claude to inspect the repository.
- `--output-format text` keeps the scratchpad to the answer instead of a JSON
  event stream.
- Redirect stdout to the scratchpad; do not mix it with progress output.

## Follow-up turns

For a follow-up, use a new print call with the relevant prior answer included
in the prompt. This is intentionally explicit: `--no-session-persistence`
means there is no hidden Claude conversation to resume, and the scratchpad is
the auditable source of context.

```bash
cd /path/to/repo && claude --print \
  --model claude-opus-4-8 \
  --permission-mode plan \
  --output-format text \
  --no-session-persistence \
  "Here is Claude's prior answer:\n$(cat <scratchpad>/claude-1.md)\n\n<follow-up prompt>" \
  > <scratchpad>/claude-2.md < /dev/null
```

Do not ask Claude to commit, modify files, or make the verdict agree with
Codex. If the consultation fails, report the command error rather than
inventing a second opinion.

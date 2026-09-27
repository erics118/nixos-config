---
name: consulting-claude
description: Use from Codex or pi when you want an independent second opinion from Claude Opus 5.5 on code, a plan, or a review, or when you need to follow up on an answer Claude already gave.
---

# Consulting Claude

Claude is a different model, so its value is disagreement. Ask it to judge,
not merely to fetch information. Preserve its verdict when reporting back,
then say explicitly where you agree or disagree.

Pin `--model claude-opus-5-5` on every call. Do not rely on Claude's user
configuration to choose the model; a later config change must not silently
change the reviewer.

Run Claude from the repository being reviewed. Use non-interactive print mode,
plan permissions, and no session persistence so a consultation cannot edit the
checkout or leave a resumable session behind. Save the response in a temp dir
and read that file after the command completes. These calls can take minutes:
run them in the foreground with the tool's timeout set to at least 10 minutes,
and never poll with `pgrep -f`.

## First turn

```bash
d=$(mktemp -d)
cd /path/to/repo && claude --print \
  --model claude-opus-5-5 \
  --permission-mode plan \
  --output-format text \
  --no-session-persistence \
  "<prompt>" > "$d/claude-1.md" < /dev/null
```

- `--print` makes the call non-interactive and returns the final answer.
- `--permission-mode plan` keeps the consultation read-only while allowing
  Claude to inspect the repository.
- `--output-format text` keeps the saved file to the answer instead of a JSON
  event stream.
- Redirect stdout to the temp dir; do not mix it with progress output.

## Follow-up turns

For a follow-up, use a new print call with the relevant prior answer included
in the prompt. This is intentionally explicit: `--no-session-persistence`
means there is no hidden Claude conversation to resume, and the saved files are
the auditable source of context.

```bash
cd /path/to/repo && claude --print \
  --model claude-opus-5-5 \
  --permission-mode plan \
  --output-format text \
  --no-session-persistence \
  "Here is Claude's prior answer:

$(cat "$d/claude-1.md")

<follow-up prompt>" \
  > "$d/claude-2.md" < /dev/null
```

Do not ask Claude to commit, modify files, or make the verdict agree with
Codex. If the consultation fails, report the command error rather than
inventing a second opinion.

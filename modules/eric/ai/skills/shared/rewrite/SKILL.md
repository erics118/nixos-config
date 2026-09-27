---
name: rewrite
description: Use when an edit would remove, condense, or restructure more than a few lines of existing prose (instructions, skills, docs, READMEs, resumes), so no detail is lost without approval
argument-hint: "<file> <goal>"
---

Change existing prose without losing a detail the user didn't approve cutting.

1. Baseline. Before the first edit, copy the file to a temp file and note the printed path: `b=$(mktemp) && cp <file> "$b" && echo "$b"`.
2. Edit in place with the edit tool, one passage per edit. Never a script, a redirect, or a whole-file write.
3. Account. Run `~/.claude/skills/rewrite/scripts/specifics <baseline> <file>` in Claude Code, or `~/.agents/skills/rewrite/scripts/specifics <baseline> <file>` in Codex and pi. For every `missing:` and `changed:` line, give one row: kept as `<quote>`, moved to `<section>`, merged into `<quote>`, or cut because `<reason>`.
4. A cut is a proposal. List the cuts on their own and restore any the user doesn't approve.
5. Finish with `git diff --stat` for the file.

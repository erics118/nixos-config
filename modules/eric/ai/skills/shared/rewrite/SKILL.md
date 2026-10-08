---
name: rewrite
description: Use when an edit would remove, condense, or restructure more than a few lines of existing prose (instructions, skills, docs, READMEs, resumes), so no detail is lost without approval
argument-hint: "<file> <goal>"
---

Change existing prose without losing a detail the user didn't approve cutting.

1. Baseline. Before the first edit, copy the file to a temp file and note the printed path: `b=$(mktemp) && cp <file> "$b" && echo "$b"`.
2. Edit in place with the edit tool, one passage per edit, even in an untracked file.
3. Account. Run `<skill dir>/scripts/specifics.sh <baseline> <file>`, where `<skill dir>` is this skill's base directory. For every `missing:` and `changed:` line, give one row: kept as `<quote>`, moved to `<section>`, merged into `<quote>`, or cut because `<reason>`. In a hard-wrapped file, a `changed:` line can be a sentence fragment. Account for it by its sentence.
4. A cut is a proposal. List the cuts on their own and wait for the user's answer. Restore every cut they don't approve.
5. Finish with `git diff --stat -- <file>`, or `git diff --no-index --stat <baseline> <file>` if the file is untracked.

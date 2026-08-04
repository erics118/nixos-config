---
name: summarize-changes
description: Summarize the working-tree, staged, or branch diff in concise BLUF style
argument-hint: [git range]
disable-model-invocation: true
---

Summarize the current changes so I can glance before committing or opening a PR. Steps:

1. Pick the diff scope:
   - If $0 given (e.g. `main`, `HEAD~3`, `main...HEAD`): diff that range.
   - Else if staged changes exist: `git diff --cached`.
   - Else: `git diff` (unstaged) plus untracked files from `git status --short`.
2. Read the diff yourself; do not paste it back.
3. Report:
   - One-line headline of the overall change.
   - A short bullet per logical change: what changed and why, referencing `file:line` where useful. Group related edits; do not enumerate every hunk.
   - Call out anything risky, incomplete, or unrelated that slipped in (debug leftovers, TODOs, formatting-only churn).
4. Do NOT commit, stage, or modify anything. Read-only summary.

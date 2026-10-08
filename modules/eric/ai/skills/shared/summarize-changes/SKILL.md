---
name: summarize-changes
description: Summarize the working-tree, staged, or branch diff in concise BLUF style
argument-hint: "[git range]"
disable-model-invocation: true
---

Summarize the current changes so I can glance before committing or opening a PR. Steps:

1. Pick the diff scope:
   - If the invocation supplies a git range (e.g. `main`, `HEAD~3`, `main...HEAD`): diff that range.
   - Else: staged (`git diff --cached`), unstaged (`git diff`), and untracked files from `git status --short`, each reported under its own heading.
2. Read the diff yourself; do not paste it back.
3. Report:
   - One-line headline of the overall change.
   - A short bullet per logical change: what changed and why, referencing `file:line` where useful. Group related edits; do not enumerate every hunk.
   - Call out anything risky, incomplete, or unrelated that slipped in (debug leftovers, TODOs, formatting-only churn).
   - For each changed prose file (docs, instructions, skills), with `<file>` relative to the repo root, run `git show <base>:<file> | <skill dir>/../rewrite/scripts/specifics.sh - <file>`, where `<skill dir>` is this skill's base directory. List the `missing:` lines. Skip files the diff adds.
     - `<base>` is `HEAD` for working-tree changes, the ref itself for a single ref or `A..B`, and `git merge-base A B` for `A...B`.
     - The new side is `<file>` in the working tree for working-tree changes or a single ref. For `A..B` or `A...B`, feed it with `<(git show B:<file>)` in place of `<file>`.
     - For a renamed file, use the old path on the base side.
     - If `git show` fails, report that. Never report the file as clean.
4. Do NOT commit, stage, or modify anything. Read-only summary.

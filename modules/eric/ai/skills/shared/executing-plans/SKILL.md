---
name: executing-plans
description: Use when implementing an approved plan from writing-plans inline, task by task, without commits.
---

# Executing Plans

The plan already did the thinking. Execute it exactly, prove every task with its check, and leave the work uncommitted in Eric's working tree.

## Rules for the whole run

- Continuous. Never pause between tasks. Eric's approval of the plan covers every task.
- Rulings, not stalls. Decide every conflict, plan defect, or choice the plan left open that you can derive from the requirements, the code, or Eric's rules. Record it as `Ruling: <what you decided> - <why> - <cost if wrong>` and keep going.
- Stop and ask only for a requirement the plan does not settle and only Eric can, an irreversible or destructive action, or anything leaving this repo.
- Read the task, not your memory of it. The plan has the exact values.

## Setup

1. Read the plan once.
2. The progress file is `.eric/plans/<plan-basename>/progress.md`. If it exists, every task with a `Task N: done` line is finished: resume at the first task without one. Otherwise run `mkdir -p .eric/plans/<plan-basename> && printf '*\n' > .eric/plans/<plan-basename>/.gitignore` and create the file with the first line `# progress - plan: <plan path>`.
3. On a fresh start, snapshot the working tree without touching the index or history, and record it as `Start: <sha>` in the progress file:
   ```bash
   t=$(mktemp); cp "$(git rev-parse --git-dir)/index" "$t"; GIT_INDEX_FILE=$t git add -A; GIT_INDEX_FILE=$t git write-tree; rm "$t"
   ```
4. Load test-driven-development if any task's check is a test.

Done when: the progress file exists and there is one todo per task.

## Per task

1. Work the steps in order. Run every command and compare its output to the step's `Expected:` line:
   - It matches: take the next step.
   - The work is wrong: use systematic-debugging. Never bend the output into matching.
   - The plan is wrong: make the smallest change that satisfies the requirements, and record a ruling.
2. Run the task's check and read its output.
3. Append `Task N: done (check: <command> -> <result>)` to the progress file, with any rulings as `Task N: Ruling: ...` lines.

Done when: every `Expected:` line was compared against real output, the check passed this session, and every deviation has a ruling line.

## Final review

Take a second snapshot the same way, and run `git diff <start> <end> > .eric/plans/<plan-basename>/final.diff`. The diff includes new files. Send it to the other model: consulting-codex from Claude, consulting-claude from codex. Give it the plan path and its Review Focus section verbatim, and ask it to report where the diff misses a requirement, breaks on a Review Focus input, or does anything the plan did not ask for.

Grade each finding by what a person using the result gets. Fix Critical and Important findings, each with its check re-run. Record a finding you decline as a ruling, and a minor one as `Final: minor (deferred): <one line>`.

Done when: every finding is fixed, ruled, or deferred, and every task's check still passes.

## Finish

Your final message lists every ruling under "Rulings I made", in order with its cost if wrong, and every deferred minor under "Deferred minors". Then delete `.eric/plans/<plan-basename>/`. The work stays uncommitted for Eric.

---
name: executing-plans-agentic
description: Implement an approved plan from writing-plans with a fresh subagent and review per task, committing on a branch
disable-model-invocation: true
---

# Executing Plans, Agentic

A fresh implementer subagent per task, a fresh reviewer after it, and one final review by the other model. You are the controller: you dispatch, rule, and keep the ledger. You never write a task's code yourself, because controller fixes pollute your context and skip review.

## Rules for the whole run

- Rulings, not stalls. Decide every conflict, plan defect, or choice the plan left open that you can derive from the requirements, the code, or the user's rules. Record it as `Ruling: <what you decided> - <why> - <cost if wrong>` and keep going.
- Stop and ask only for a requirement the plan does not settle and only the user can, or an action the Decisions and Git rules of the global instructions reserve for the user.
- Commits. Invoking this skill is the instruction to commit, on the plan's branch only, one or more commits per task.
- Hand artifacts over as files. Everything pasted into a dispatch or printed back stays in your context for the rest of the run.
- Always pass the model explicitly, since an omitted model inherits the session's:
  - haiku: the brief contains the complete content, so the work is transcription plus checks, or a one-file mechanical fix
  - sonnet: prose-only briefs, multi-file work, every task review
  - opus: design judgment, subtle state or concurrency, fix rounds 4-5

## Setup

1. If `git config --get eric-agent.commit` does not print `branch` or `on`, stop: tell the user this skill commits per task, so it needs one of those levels in this repo, or they can use executing-plans.
2. Read the plan once.
3. If you are on `main` or `master`, run `git switch -c plan/<topic>`.
4. The workspace is `.eric/plans/<plan-basename>/`, where `<plan-basename>` is the plan file name without `.md`, and the ledger is `progress.md` inside it.
   - If the ledger exists, every task with a `Task N: complete` line is done. Resume at the first task without one. Trust the ledger and `git log` over your recollection.
   - Otherwise run `mkdir -p .eric/plans/<plan-basename>` and create the ledger with the first line `# ledger - plan: <plan path>` and a second line `Merge base: <git rev-parse HEAD>`.
5. Pre-flight. For every task that consumes what an earlier task produces (the Interfaces blocks), write one ledger row: the two tasks, what one produces against what the other consumes, and what you found. Rule on each conflict. If no tasks share anything, write `Pre-flight: no shared interfaces`.
6. Create one task-list item per plan task.

Done when: the ledger has its plan line, merge base, and pre-flight rows, and there is one todo per task.

## Per task

### 1. Dispatch the implementer

Run `git rev-parse HEAD` and ledger `Task N: base <sha>`. From the repo root, run `<skill dir>/scripts/brief.sh PLAN_FILE N`, where `<skill dir>` is this skill's base directory. It writes the task's text to `<workspace>/task-N-brief.md` and prints the path. The dispatch holds only:

1. one line on where this task fits
2. the task's deliverable and the repo path
3. the brief path: "read this first, it is your requirements, use its values verbatim"
4. the plan's Global Constraints verbatim, since the brief holds only the task's own section
5. interfaces and rulings from earlier tasks that the brief cannot know
6. the report path `<workspace>/task-N-report.md`

Use [implementer-prompt.md](implementer-prompt.md). Never run two implementers at once. When several tasks are the same tiny edit across files, send them as one batch and review them as one unit.

### 2. Handle the report

- DONE: review it.
- DONE_WITH_CONCERNS: read the concerns. Fix correctness or scope concerns before review.
- NEEDS_CONTEXT: supply what is missing and resume it.
- BLOCKED: change something before retrying: more context, a stronger model (haiku, then sonnet, then opus), a smaller task, or a ruling on the plan. Never the same retry.

### 3. Review the task

From the repo root, run `<skill dir>/scripts/review-package.sh PLAN_FILE <task base sha> HEAD`. Dispatch a sonnet reviewer with [reviewer-prompt.md](reviewer-prompt.md), scope `task`: the brief, the report, the package path, and the plan's Global Constraints verbatim. Write the dispatch without pre-judging. If it contains "do not flag" or "at most Minor", delete that line.

Resolve each `Cannot verify from diff` item yourself. A real gap joins the findings.

### 4. The fix loop

Minor findings go straight to the ledger as `Task N: minor (deferred): <one line>`. Rule first on a finding that conflicts with the plan's own text. A requirement miss, or any Critical or Important finding, starts the loop. Each round is one fix plus one scoped re-review, five rounds at most. Before each fix round, run `git rev-parse HEAD` and ledger `Task N: fix base R/5 <sha>`.

- Rounds 1-3: resume the same implementer with the open findings verbatim.
- Rounds 4-5: a fresh opus implementer, told "a prior implementer tried this 3 times, read the report file".
- Every round: from the repo root, run `<skill dir>/scripts/review-package.sh PLAN_FILE <fix base sha> HEAD` over the fix range, dispatch the reviewer with scope `re-review` and the findings verbatim, and ledger `Task N: fix round R/5 (<X> addressed, <Y> open; commits <first short sha>..<last short sha>)`.

After round 5, adjudicate each open finding. If it is wrong or nothing builds on it, park it: `Task N: parked - <finding> - Ruling: <why>`. If it is load-bearing, rule on the smallest unblocking change and carry that ruling into the next dispatch.

### 5. Complete the task

Ledger `Task N: complete (commits <base7>..<head7>, review clean)`, or `(..., K parked)`.

Done when: the review is clean, or every open finding is parked with a ruling at the cap.

## Final review

From the repo root, run `<skill dir>/scripts/review-package.sh PLAN_FILE <merge base> HEAD`. Send the package to codex via consulting-codex, using [reviewer-prompt.md](reviewer-prompt.md) with scope `branch`, the plan path, the Review Focus section verbatim, and a pointer to the ledger's `Ruling:`, `parked`, and `minor (deferred)` lines.

Grade each finding by what a person using the result gets, not by its label. Send all Critical and Important findings to one opus fix subagent, then run one scoped re-review of its range. Adjudicate what remains as in the fix loop. There is no second fix wave. Ledger each minor as `Final: minor (deferred): <one line>`.

Done when: every finding is fixed, parked, or deferred.

## Finish

Your final message lists every ledger `Ruling:` line under "Rulings I made", in order with its cost if wrong, and every deferred minor under "Deferred minors". Both lists are exhaustive. Then delete the workspace. The branch stays for the user to merge or discard.

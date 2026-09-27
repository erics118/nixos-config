---
name: writing-plans
description: Use when a multi-step change needs a written implementation plan before any work, or when asked for a plan.
---

# Writing Plans

Write a plan that an engineer with zero context on this codebase can execute task by task without asking anything. The plan does the thinking, so execution is transcription plus checks.

## 1. Settle the requirements

Read the request and the code or files it touches first, so you never ask for a fact you could look up. For each choice of mechanism, cite a `redesign` verdict, or fill its survey slots (job, platform, standard tools, repo, zero-code, project rules) here and use the verdict as grilling's recommended answer. Plans never edit code. Then run the grilling skill on what only Eric can decide: purpose, scope, constraints, and choices between valid options.

Done when: Eric confirms the shared understanding, and every requirement has an exact value or a decision.

## 2. Map the files

List every file the plan creates or modifies, each with its one responsibility. Follow the codebase's existing patterns. Split a file only when a task already modifies it and it has grown unwieldy.

Done when: every file any task touches is listed with its responsibility.

## 3. Cut the tasks

A task is the smallest unit that a reviewer could reject while approving its neighbor, and it ends on a deliverable its check can confirm. Fold setup, config, and docs into the task whose deliverable needs them.

Every task names its check: the command or observation that proves it done, with the expected result. Pick the check the work allows:

- Code with a test harness and a behavior you can specify: TDD per test-driven-development. The failing test is the first step.
- Anything else (docs, config, infra, layout, glue, exploration): a build, a run, a rendered page, or a status read, whose expected output you state before the work.

Each step is one action of 2-5 minutes.

Done when: every task has a deliverable and a check with an expected result, and no task exists only to set up another.

## 4. Write the plan

Save it to `.eric/plans/YYYY-MM-DD-<topic>.md` at the repo root, in the format in [format.md](format.md).

Every step carries its real content: the exact code, text, or config to write, and the exact command with its `Expected:` output. A plan is broken if it contains any of these:

- "TBD", "TODO", "fill in later"
- "add error handling", "handle edge cases", or similar, with no content
- "write tests for the above" with no test
- "similar to Task N" (repeat the content, since tasks are read alone)
- a name that no task defines

Done when: the file exists and every task follows the format.

## 5. Self-review

Check the plan against the settled requirements, not your notes:

- Coverage: every requirement points to the task that delivers it. Add a task for any gap.
- Placeholders: search the plan for every broken pattern in step 4.
- Consistency: every name a task consumes matches the task that produces it.
- Review Focus: list the inputs and failure modes the requirements imply but no task's check exercises. The five most likely to bite go in the plan's Review Focus section, each with its check added to the task that owns it.

Fix what you find in place.

Done when: all four checks pass with nothing open.

## 6. Hand off

Link the plan and recommend an executor in one sentence: executing-plans (inline, no commits) for most work, or executing-plans-agentic (Claude only: subagent per task, reviews, commits on a branch, so the repo needs `agent.autonomous` set) when tasks are many or a mistake is costly. Wait for Eric to approve the plan and pick the executor.

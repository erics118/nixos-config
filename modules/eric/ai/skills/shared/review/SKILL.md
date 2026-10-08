---
name: review
description: Red-team the diff, a file, or a plan with the auditor agent and the other model in parallel, then merge their findings
argument-hint: "[empty for uncommitted changes | file | area | plan]"
disable-model-invocation: true
effort: high
---

Attack the target from the lens that it is wrong. Be blunt, do not soften, do not praise to balance. The target is the uncommitted diff unless the invocation names a file, area, or pasted plan.

## 1. Brief

Write one brief to the scratchpad: the target (the diff via `git diff HEAD` plus untracked files, the named paths, or the plan text), the angles below, and the finding format. For a plan, judge the design on the five checks in the Decisions rules of the global instructions and its assumptions, not style, and do not demand code that does not exist yet.

Done when: the brief file exists and names every path in scope.

## 2. Two reviewers, in parallel

Give both the same brief, before reading anything yourself:

- First start the `auditor` agent in the background: the Agent tool under Claude, native subagents under Codex, pi-subagents under pi.
- Then run the other model as its consulting skill says: `consulting-codex` under Claude, `consulting-claude` under Codex or pi.

Read the target yourself while they run, or after if the other model's call blocks, so you can judge their findings.

Done when: both have returned, or one failed and you say which and why.

## 3. Merge

Verify the decisive line of every finding against the current code before keeping it. Drop findings that are vague, misread intent, or relocate complexity, and say which you dropped. Merge duplicates and mark each finding's source: auditor, the other model, or both. Agreement is high confidence. Where they disagree, dig into why instead of averaging. Quote the other model's verdict verbatim.

Done when: every finding is kept with its line checked, or listed as dropped with a reason.

## Angles

Label every finding with its angle:

1. Necessity: do we actually need this? What breaks if it is deleted? How do the platform
   and its standard tools already do this job, and is this reinventing that? Is it solving a
   problem I really have, or a hypothetical one (YAGNI)? Does something existing already
   do it?
2. Correctness: did we do it right? Does it actually do what I intended, with the logic
   and cases handled correctly? Wrong assumptions baked into the happy path.
3. Unconsidered breakage: how is it broken in a way I did not think about? Edge cases,
   failure and error paths, adverse or malformed inputs, concurrency and ordering, and
   bad interactions with existing code. Name the assumptions that could be false.
4. Consequences: what does this make worse or harder elsewhere? Hidden coupling it
   introduces, what it makes harder to change or undo later, and downstream effects on
   the rest of the system.

## Report

Number the findings, worst first, so the user can answer "fix 1, 3". Each finding: the angle, the source, what specifically (`file:line` for code, or the step or section it lands on for a plan), why it is a problem, and how bad it is (blocker / worth fixing / nit).

End with a blunt verdict: ship as-is, fix first, or scrap and redo. If the target is actually sound, say so plainly rather than inventing objections. Change no files until the user names which findings to fix.

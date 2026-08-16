---
name: systematic-debugging
description: Use when a bug, test failure, nix eval/build failure, or any unexpected behavior appears, before proposing a fix. Find the root cause first.
---

# Systematic Debugging

## Iron law

NO FIX WITHOUT A ROOT CAUSE FIRST. A fix aimed at the symptom is a failure, even if it makes the error go away.

This holds hardest exactly when it is tempting to skip: under time pressure, on an "obvious" one-liner, or after a previous fix did not stick.

Work the phases in order. Each ends on a check.

## Phase 1: find the root cause

- Read the error in full. Stack traces, nix eval traces, line numbers, and codes usually name the cause outright. Do not skim past them.
- Reproduce it. Know the exact trigger and whether it is every time. Not reproducible means gather more data, not guess.
- Check what changed. `git diff`, recent commits, a flake input bump, a new import, an env difference.
- For a multi-step path (flake eval to build to activation, service to service), add evidence at each boundary and run once to see which boundary breaks before theorizing about any one of them.
- Trace a bad value backward to where it originates, not where it surfaces. Fix at the source.

Done when: you can state what is wrong and why, from evidence, not suspicion.

## Phase 2: compare against what works

- Find a working instance of the same pattern in the repo or upstream.
- Read the reference completely, not the name or your memory of it.
- List every difference between working and broken, however small. Do not pre-dismiss any as "cannot matter."

Done when: you can name the difference that accounts for the failure.

## Phase 3: one hypothesis at a time

- State it: "X is the root cause because Y."
- Test it with the smallest possible change, one variable.
- Worked: go to Phase 4. Did not: form a new hypothesis. Do not stack another fix on top.
- If you do not understand something, say so and dig. Do not pretend.

Done when: a single hypothesis is confirmed by a minimal test.

## Phase 4: fix the cause

- Write the failing case first: the smallest reproduction, automated if the project has a harness, a one-off script otherwise.
- Make one change addressing the root cause. No "while I'm here" edits, no bundled refactor.
- Verify: the case passes, nothing else broke, the original issue is actually gone.

Done when: the reproduction passes and no other check regresses.

## When three fixes have failed, stop fixing

If each attempt reveals a new problem somewhere else, or every fix would need "massive refactoring," the architecture is wrong, not the hypothesis. Stop and raise it with Eric before attempt four.

## Stop signals

Any of these means return to Phase 1:

- "Quick fix now, understand it later."
- Proposing a fix before tracing the data flow.
- Changing several things at once to see what sticks.
- Skipping the failing case to verify by hand.
- A second fix stacked on a first that did not work.

---
name: architecture-review
description: Use when asked to review the architecture or design of existing code, or when a full audit reaches its architecture pass.
argument-hint: "[empty for whole repo | area]"
effort: high
---

Judge whether the existing code is split the right way across its parts, and name the larger refactors worth doing. Read the actual code, design records, and git history, never judge from names. Read-only: change no files. These are personal and small-group projects, so a finding needs a cost the code or its history shows, not a pattern a bigger team would want. A part is a module, process, or prompt that owns its own code or decisions. A skill's or agent's prose counts, since an agent acts on it.

1. Boundaries. List every boundary between two parts: a language or process seam, a shared file or format, an owner of shared state, a decision more than one part makes. Give each one row: the two sides, how often it is crossed (once, per run, per item, per call), representative call sites, the workarounds it forces (timeouts, retries, polling, chunked calls, code built as strings) with `file:line`, and the constraint that put it there, with evidence (a design record, a commit, a platform limit you checked). Write `none` when no source explains it. A `none` boundary, or one whose constraint no longer holds, is a candidate finding. Done when every part in scope sits on at least one row.
2. Trace. Follow one main operation end to end across every boundary it crosses, with `file:line` at each crossing. Note each place the same decision, conversion, or workaround happens again.
3. Check each row and the trace for:
   - one decision implemented on both sides of a seam, so every fix lands twice
   - a process, IPC, or serialization boundary crossed per action where per run would do
   - one workaround repeated at every call site
   - state with more than one owner
   - a load-bearing invariant across parts that only prose enforces
   - a boundary whose constraint still holds but whose mechanism forces workarounds: name the mechanism a fresh design would pick (survey it as in step 2 of [the approach survey](../approach/survey.md)) and the workarounds it removes
4. Synthesize one target shape for the whole scope, not one per finding. With many parts, dispatch read-only `auditor` workers for the evidence in steps 1 and 2, but write the target shape yourself.

Report each finding with: the current shape, the problem with `file:line` evidence, the recurring cost (what it makes every future change pay), the target shape, the first step toward it, and what should stay as is. Rate recurring cost and migration risk high, medium, or low. Rank by cost, then by lower risk. A finding with no recurring cost is note-only. If the split is already right, say so.

Applying a finding is a separate request. A small one is a direct edit. A multi-step one goes to `writing-plans`.

---
description: Red-team code or a plan from hostile angles (necessity, correctness, unconsidered breakage, consequences)
argument-hint: [empty for uncommitted changes | file | area | plan] [--adversary codex]
disable-model-invocation: true
---

Attack the target in $ARGUMENTS. View it from the lens that it is wrong and try to break it. This is an
adversarial review, not a cooperative one: be blunt, do not soften, do not praise to
balance. Read the real source or plan before judging, never from names alone.

Scope: default to the current working diff. If $ARGUMENTS names a file/dir/area or is a
pasted plan or idea, review that instead. Strip any `--adversary` flag out of
$ARGUMENTS before interpreting scope.

If `--adversary codex` is present, add codex as a second independent reviewer. Pass it the
same instruction block and scope; it is a different model on purpose.

- Do your own pass first, exactly as below.
- Use the `consulting-codex` skill for the mechanics.
- Present codex's output verbatim under its own `## Codex` heading. Do not summarize,
  soften, or reconcile away its findings, especially its verdict.
- After both passes, add a short `## Reconciliation`: where you agree (high confidence) and
  where you disagree (dig into why, do not just average). Keep every verdict intact.

This is for work I just produced and am unsure about, whether that is code or a plan I
have not built yet. For a plan, judge the design and its assumptions, not style, and do
not demand code that does not exist yet. Hit the target from each of these angles and
label every finding with its angle:

1. Necessity: do we actually need this? What breaks if it is deleted? Is it solving a
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

For each finding: the angle, what specifically (`file:line` for code, or the step or
section it lands on for a plan), why it is a problem, and how bad it is (blocker / worth
fixing / nit).

End with a blunt verdict: ship as-is, fix first, or scrap and redo. If the target is
actually sound, say so plainly rather than inventing objections. Read-only: propose
nothing to apply, change no code, ask before any remediation.

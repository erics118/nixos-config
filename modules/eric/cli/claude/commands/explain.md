---
description: Explain what a feature does, how it fits the codebase, why it exists, and its idioms
argument-hint: [empty for uncommitted changes | file | dir | feature name]
disable-model-invocation: true
---

Explain a component by reading the actual source, not from memory. Steps:

1. Scope: default to the current working diff, explaining the changed component(s). If $ARGUMENTS names a file/dir/feature, explain that instead: resolve it to the real file(s)/dir, and if ambiguous list the candidates and ask which one before continuing.
2. Read the component fully, plus enough of its neighbors to see how it is wired: who imports/calls it, what it imports/calls, and the module/layer it sits in.
3. Explain, covering:
   - What it does: the behavior in one or two lines.
   - How it fits: where it plugs into the rest of the repo (callers, module wiring, data/control flow in and out). Reference `file:line`.
   - Why it exists: the problem it solves and what would break or be worse without it.
   - Idioms: for each non-obvious pattern, convention, or workaround it uses, why it is done that way (constraints, alternatives rejected, gotchas). Distinguish deliberate choices from incidental style.
4. Flag anything that looks dead, redundant, or inconsistent with the rest of the codebase, but do not change it. Read-only explanation.

---
name: overkill
description: Use when a proposal, plan, or change might be more than the job needs, to judge it part by part before building.
argument-hint: "[empty for the current proposal | file | plan]"
---

Answer one question: is the current proposal, or the target given, overkill? It is a question, not a build order, so change no files. Judge on the merits and put the verdict up front.

1. Job. State the job in one line, as the outcome the user asked for.
2. Parts. List every part of the proposal: each file, setting, skill, step, check, or abstraction.
3. For each part, answer: what breaks or gets worse for the user without it? Cite the fact. A part that guards against a case that can't happen here, duplicates another part, or serves a case nobody asked for is overkill.
4. Reply with `Cut: <part> - <reason>` and `Keep: <part> - <what it prevents>` lines. If nothing is overkill, say so in one line.

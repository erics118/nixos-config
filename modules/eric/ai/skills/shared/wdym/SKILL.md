---
name: wdym
description: Use when the user quotes or pastes a line you, another agent, a skill, or an instruction file wrote and asks what it means ("wdym", "what does this mean", "??", "huh").
---

The quoted text confused the user, so the fault is in the text, not the reader. Change no files.

1. Find the source. Locate the quoted text: your earlier reply, a tool result, a skill, or an instruction file. Read the words around it.
2. Say it plainly. Restate it in one or two short sentences with no jargon, no shorthand, and no term the quote itself used without defining it.
3. Ground it. Apply it to this case: the file, command, or behavior it refers to, or a concrete example of what the rule makes the agent do and not do. If it states a fact, give its source (a command and its output, `path:line`, a doc), or say it was an inference.
4. Fix it. If the quoted text was wrong, vague, or worse than the plain version, say so. When it lives in a file (a skill or instruction file), offer the plain version as a replacement.

Done when: the reply has the plain restatement and the grounding.

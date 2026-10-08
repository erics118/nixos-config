---
name: side
description: Open a fork, a handoff, or a fresh Claude in a tmux split beside this conversation
argument-hint: "[fork [question] | handoff <task> | new]"
disable-model-invocation: true
---

Open another Claude in a tmux split beside this one with the `agent-side claude` command, run through Bash. Pass the user's text as one single-quoted argument, escaping any `'` in it.

- **`handoff` followed by a task:** first write a handoff document as `~/.claude/skills/handoff/SKILL.md` describes, focused on the task. Then run `agent-side claude handoff <doc path> '<task>'`.
- **anything else**, including `handoff` alone: run `agent-side claude <first word> '<rest>'`, or `agent-side claude <first word>` when there is no rest, or plain `agent-side claude` when there are no arguments. The script checks the mode and tmux.

Reply with the line `agent-side` printed and nothing else.

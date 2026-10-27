---
name: side
description: Open a fork, a handoff, or a fresh Claude in a tmux or Rex split beside this conversation
argument-hint: "[fork [question] | handoff <task> | new]"
disable-model-invocation: true
---

Open another Claude in a tmux or Rex split beside this one with `~/.agents/bin/agent-side.sh claude`, run through Bash. Pass the user's text as one single-quoted argument, escaping any `'` in it.

- **`handoff` followed by a task:** first write a handoff document as `~/.claude/skills/handoff/SKILL.md` describes, focused on the task. Then run `~/.agents/bin/agent-side.sh claude handoff <doc path> '<task>'`.
- **anything else**, including `handoff` alone: run `~/.agents/bin/agent-side.sh claude <first word> '<rest>'`, or `~/.agents/bin/agent-side.sh claude <first word>` when there is no rest, or plain `~/.agents/bin/agent-side.sh claude` when there are no arguments. The script checks the mode and whether it runs in tmux or Rex.

Reply with the line `agent-side.sh` printed and nothing else.

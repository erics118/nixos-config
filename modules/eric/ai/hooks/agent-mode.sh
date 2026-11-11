#!/usr/bin/env bash
# on each prompt in autonomous mode, give the agent the mode and its rules, so neither depends on memory
# the mode file is written by bin/agent-mode.sh. manual mode adds nothing
# usage: agent-mode.sh, with session_id in the JSON on stdin
# always exit 0, so a failure never blocks the prompt
id=$(jq -r '.session_id // empty' 2>/dev/null)
mode=${XDG_STATE_HOME:-$HOME/.local/state}/agent-mode/$id
[[ -n $id && $(cat "$mode" 2>/dev/null) == autonomous ]] || exit 0
rules=$(cat "$(dirname "$(realpath "$0")")/../skills/claude/autonomous/rules.md" 2>/dev/null)
jq -n --arg c "Mode: autonomous. Follow these rules until a prompt arrives without this line.
${rules:-The autonomous rules file is missing, so say so and work in manual mode.}" \
  '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$c}}'
exit 0

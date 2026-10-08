#!/usr/bin/env bash
# record on the agent's tmux pane how to resume its session, so a tmux restore relaunches it (see tmux/agent-resume.sh)
# usage: tmux-agent-resume.sh claude|codex|pi, with session_id and cwd in the JSON on stdin
# always exit 0, so a failure never blocks the agent
input=$(cat)
id=$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null)
[[ -n $id ]] || exit 0
case $1 in
claude) cmd="claude --resume $(printf %q "$id")" ;;
codex) cmd="codex resume $(printf %q "$id")" ;;
pi) cmd="pi --session $(printf %q "$id")" ;;
*) exit 0 ;;
esac

if [[ -n ${TMUX_PANE:-} ]]; then
  # the agent is the hook's parent, unless a shell runs the hook
  agent=$PPID
  [[ $(ps -o comm= -p "$agent") =~ (^|/)-?(sh|bash|zsh|dash)$ ]] && agent=$(ps -o ppid= -p "$agent" | tr -d ' ')
elif [[ $1 == codex ]]; then
  # codex runs hooks in its background daemon, outside any pane.
  # the pane is the only one whose shell started a codex in the session's directory
  cwd=$(jq -r '.cwd // empty' <<<"$input")
  matches=$(tmux list-panes -a -F '#{pane_id} #{pane_pid}' 2>/dev/null | while read -r pane pane_pid; do
    for child in $(pgrep -P "$pane_pid" -x codex); do
      [[ $(lsof -a -d cwd -p "$child" -Fn 2>/dev/null | sed -n 's/^n//p') == "$cwd" ]] && echo "$pane $child"
    done
  done)
  [[ -n $matches && $(wc -l <<<"$matches") -eq 1 ]] || exit 0
  read -r TMUX_PANE agent <<<"$matches"
else
  exit 0
fi

# only an agent started from the pane's shell owns the pane, not one another agent runs there
pane_pid=$(tmux display -p -t "$TMUX_PANE" '#{pane_pid}' 2>/dev/null) || exit 0
[[ $(ps -o ppid= -p "$agent" | tr -d ' ') == "$pane_pid" ]] || exit 0
tmux set -p -t "$TMUX_PANE" @agent_pid "$agent" \; set -p -t "$TMUX_PANE" @agent_resume "$cmd" 2>/dev/null
exit 0

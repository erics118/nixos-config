#!/usr/bin/env bash
# save and restore the resume command of each pane's agent alongside tmux-resurrect (see main.conf).
# ai/hooks/tmux-agent-resume.sh records the command on the pane
# usage: agent-resume.sh save|restore

# the pinned resurrect always saves here, and creates it before its post-save hook runs
dir=$HOME/.tmux/resurrect

case $1 in
save)
  # = matches the session name exactly, so a name like "top" is not read as a pane token
  tmux list-panes -a -F $'=#{session_name}:#{window_index}.#{pane_index}\t#{pane_pid}\t#{@agent_pid}\t#{@agent_resume}' |
    while IFS=$'\t' read -r target pane_pid agent cmd; do
      # skip a pane whose agent has exited. an agent-side pane's agent is the pane's own process
      if [[ -n $cmd && ($agent == "$pane_pid" || $(ps -o ppid= -p "$agent" 2>/dev/null | tr -d ' ') == "$pane_pid") ]]; then
        printf '%s\t%s\n' "$target" "$cmd"
      fi
    done >"$dir/agents.tmp" && mv "$dir/agents.tmp" "$dir/agents"
  ;;
restore)
  [[ -f $dir/agents ]] || exit 0
  while IFS=$'\t' read -r target cmd; do
    # a pane whose agent still runs was not restored, so typing there would message the agent
    agent=$(tmux display -p -t "$target" '#{@agent_pid}' 2>/dev/null)
    [[ -n $agent ]] && kill -0 "$agent" 2>/dev/null && continue
    tmux send-keys -t "$target" -l "$cmd" \; send-keys -t "$target" Enter 2>/dev/null
  done <"$dir/agents"
  ;;
esac

#!/usr/bin/env bash
# save and restore the resume command of each pane's agent alongside tmux-resurrect (see main.conf).
# ai/hooks/tmux-agent-resume.sh records the command on the pane
# usage: agent-resume.sh save|restore

# resurrect's save dir: @resurrect-dir, else the pinned plugin's default ~/.tmux/resurrect
# newer resurrect falls back to the xdg dir when ~/.tmux/resurrect is missing, so this does too
dir=$(tmux show -gqv @resurrect-dir)
dir=${dir/#\~/$HOME}
if [[ -z $dir ]]; then
  dir=$HOME/.tmux/resurrect
  [[ -d $dir ]] || dir=${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect
fi

case $1 in
save)
  # = matches the session name exactly, so a name like "top" is not read as a pane token
  tmux list-panes -a -F $'=#{session_name}:#{window_index}.#{pane_index}\t#{pane_pid}\t#{@agent_pid}\t#{@agent_resume}' |
    while IFS=$'\t' read -r target pane_pid agent cmd; do
      # skip a pane whose agent has exited
      if [[ -n $cmd && $(ps -o ppid= -p "$agent" 2>/dev/null | tr -d ' ') == "$pane_pid" ]]; then
        printf '%s\t%s\n' "$target" "$cmd"
      fi
    done >"$dir/agents.tmp" && mv "$dir/agents.tmp" "$dir/agents"
  ;;
restore)
  [[ -f $dir/agents ]] || exit 0
  while IFS=$'\t' read -r target cmd; do
    tmux send-keys -t "$target" -l "$cmd" \; send-keys -t "$target" Enter 2>/dev/null
  done <"$dir/agents"
  ;;
esac

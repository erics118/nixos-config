#!/usr/bin/env bash
# open the named tmux popup, close it when it is already open, or switch to it from another one.
# wezterm's cmd keys and the tmux prefix keys both run this, since an open popup takes every key

usage='Usage: tmux-popup sessions|projects|scratch|files [CLIENT_TTY]'
case ${1-} in
sessions | projects | scratch | files) kind=$1 ;;
-h | --help)
  echo "$usage"
  exit
  ;;
*)
  echo "$usage" >&2
  exit 2
  ;;
esac
client=${2:-$(tmux display -p '#{client_tty}')}

# a popup takes its PATH from what opened it, which from wezterm is the gui's and lacks the user's tools.
# so it reruns inside the tmux server, whose environment the key bindings use too
if [[ -z ${TMUX_POPUP_IN_SERVER:-} ]]; then
  exec tmux run-shell -b "TMUX_POPUP_IN_SERVER=1 tmux-popup $(printf %q "$kind") $(printf %q "$client")"
fi

# every query targets the client's session, since a format without a target follows TMUX_PANE,
# which can be the scratch shell's own pane. an unknown client ends here, where display -c would fall back to another
session=$(tmux list-clients -F $'#{client_tty}\t#{client_session}' | awk -F '\t' -v c="$client" '$1 == c { print $2 }')
[[ -n $session ]] || exit 0
target="=$session:"

modal() {
  tmux display -t "$target" -p '#{window_modal_pane}'
}

# both picker views are one fzf, which switches between them itself
family() {
  case $1 in
  sessions | projects) echo picker ;;
  *) echo "$1" ;;
  esac
}

# which popup a pane is, from the command open started it with
open_family() {
  case $(tmux display -t "$1" -p '#{pane_start_command}') in
  *sesh-pick*) echo picker ;;
  *yazi*) echo files ;;
  *SCRATCH*) echo scratch ;;
  *) echo other ;;
  esac
}

open() {
  local pane title args
  pane=$(tmux display -t "$target" -p '#{pane_id}')
  case $kind in
  sessions | projects)
    title=sesh
    args=(-w 40% -h 60% -e "SESH_CLIENT_TTY=$client" sesh-pick --popup)
    [[ $kind == sessions ]] && args+=(--sessions)
    ;;
  # each session gets its own hidden scratch-<session>, which tmux/keys.conf gives its own key tables.
  # the inner tmux drops TMUX, since a floating pane has it set and refuses a nested client
  scratch)
    title=scratch
    # shellcheck disable=SC2016
    args=(-x P -y P -w 100% -h 40% -e "SCRATCH=scratch-$session" -e "SCRATCH_SOCKET=$(tmux display -p '#{socket_path}')"
    'TMUX= tmux -S "$SCRATCH_SOCKET" new -A -s "$SCRATCH" \; set status off \; set prefix None \; set key-table scratch')
    ;;
  files)
    title=yazi
    args=(-w 90% -h 90% yazi)
    ;;
  esac
  # display-popup waits for the popup to close, so it runs in the background, and the popup outlives it.
  # -d expands against the pane, and falls back to the session's directory when tmux cannot read the pane's
  tmux display-popup -c "$client" -t "$pane" -E -d '#{pane_current_path}' -s 'bg=#1e1e2e' -S 'fg=#6c7086' \
    "${args[@]}" &
  local popup=''
  for _ in $(seq 50); do
    popup=$(modal)
    [[ -n $popup ]] && break
    sleep 0.01
  done
  # a popup of another kind means a second press opened its own first, and this display-popup did nothing
  [[ -n $popup && $(open_family "$popup") == "$(family "$kind")" ]] || return 0
  # set on the pane, since display-popup -b leaves the lines single and its -T title follows the program's own
  tmux set -p -t "$popup" pane-border-lines rounded \; \
    set -p -t "$popup" pane-border-status top \; \
    set -p -t "$popup" pane-border-format "#[align=centre]#[fg=#cdd6f4] $title "
}

# the picker closes through fzf, which hides the cursor on its way out, and yazi through q,
# which asks first when a copy or move is still running. fails when the popup stays open
close() {
  case $(open_family "$1") in
  picker) tmux send-keys -t "$1" Escape ;;
  files) tmux send-keys -t "$1" q ;;
  *) tmux kill-pane -t "$1" ;;
  esac
  for _ in $(seq 50); do
    [[ -z $(modal) ]] && return
    sleep 0.02
  done
  return 1
}

current=$(modal)
if [[ -z $current ]]; then
  open
  exit
fi
was=$(open_family "$current")
if [[ $was == picker && $(family "$kind") == picker ]]; then
  # fzf takes ctrl-alt-k/p to switch views, or to close the view already shown
  if [[ $kind == sessions ]]; then
    tmux send-keys -t "$current" C-M-k
  else
    tmux send-keys -t "$current" C-M-p
  fi
else
  close "$current" || exit 0
  [[ $was == "$(family "$kind")" ]] || open
fi

#!/usr/bin/env bash
# ring the bell in the agent's tmux pane, so tmux and wezterm mark its tab when it finishes or waits
# always exit 0, since a Stop hook that exits 2 keeps the agent running
[[ -n ${TMUX_PANE:-} ]] || exit 0
tty=$(tmux display -p -t "$TMUX_PANE" '#{pane_tty}' 2>/dev/null) && printf '\a' >"$tty" 2>/dev/null
# tmux flags no bell on a window a client shows, so mark it for @alert and @session-alert (see tmux/alerts.conf).
# a focused client showing the window means it was seen
win=$(tmux display -p -t "$TMUX_PANE" '#{window_id}' 2>/dev/null) &&
  ! tmux list-clients -F '#{client_flags} #{window_id}' 2>/dev/null | grep -q "focused.* $win\$" &&
  tmux set -w -t "$TMUX_PANE" @bell 1 2>/dev/null
exit 0

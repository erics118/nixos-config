#!/usr/bin/env bash
# ring the bell in the agent's tmux pane, so tmux and wezterm mark its tab when it finishes or waits
# always exit 0, since a Stop hook that exits 2 keeps the agent running
[[ -n ${TMUX_PANE:-} ]] || exit 0
tty=$(tmux display -p -t "$TMUX_PANE" '#{pane_tty}' 2>/dev/null) && printf '\a' >"$tty" 2>/dev/null
exit 0

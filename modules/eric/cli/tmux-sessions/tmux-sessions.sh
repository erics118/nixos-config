#!/bin/sh
# print each tmux session as its name, a tab, and its alert from @session-alert (see tmux/tabline.conf)
# leaves out the hidden scratch-<session> popups (see tmux/keys.conf)
# any arguments go to tmux before the command, such as -L for another server
# rtmux copies it as is to hosts outside this config, so it stays POSIX sh that needs only tmux

case ${1-} in
-h | --help)
  echo 'Usage: tmux-sessions [TMUX_OPTION...]'
  exit
  ;;
esac

tab=$(printf '\t')
# no server prints nothing, which is not an error
# -u keeps the tab, which tmux prints as _ without a utf-8 locale, as in the wezterm gui's environment
tmux -u "$@" list-sessions -F "#{session_name}$tab#{E:@session-alert}" 2>/dev/null | grep -v '^scratch-'
exit 0

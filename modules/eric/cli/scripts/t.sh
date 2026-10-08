#!/usr/bin/env bash
# no arg opens the sesh picker. an arg is resolved by sesh: a session, config
# entry, dir, or zoxide match, so sessions are always named after their dir

set -euo pipefail

case ${1-} in
-h | --help)
  cat <<EOF
Usage: t [SESSION | --ls]

  (none)    pick a session in fzf (sesh-pick)
  SESSION   connect to a sesh session, config entry, dir, or zoxide match
  --ls      list tmux sessions
EOF
  ;;
--ls) exec tmux ls ;;
*) exec sesh-pick "$@" ;;
esac

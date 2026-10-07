#!/usr/bin/env bash
# no arg opens the sesh picker. an arg is resolved by sesh: a session, config
# entry, dir, or zoxide match, so sessions are always named after their dir

set -euo pipefail

case ${1-} in
--ls) exec tmux ls ;;
*) exec sesh-pick "$@" ;;
esac

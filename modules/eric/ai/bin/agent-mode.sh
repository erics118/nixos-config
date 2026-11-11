#!/usr/bin/env bash
# set or print this claude session's mode, which hooks/agent-mode.sh and the statusline read
# usage: agent-mode.sh [on|off], with CLAUDE_CODE_SESSION_ID set
set -euo pipefail
id=${CLAUDE_CODE_SESSION_ID:?not in a claude session}
dir=${XDG_STATE_HOME:-$HOME/.local/state}/agent-mode
mkdir -p "$dir"
case ${1:-} in
on) echo autonomous >"$dir/$id" ;;
off) echo manual >"$dir/$id" ;;
'') ;;
*)
  echo 'usage: agent-mode.sh [on|off]' >&2
  exit 2
  ;;
esac
cat "$dir/$id" 2>/dev/null || echo manual

#!/usr/bin/env bash
# block agent commits unless the repo opted in with `git config agent.autonomous true`.
# only the user sets that flag, so agents may not write it
set -u
source "$(dirname "$0")/lib.sh"

hook_require rg jq git awk
hook_read_command
hook_command_dir
hook_bare_command

printf '%s' "$HOOK_BARE" | rg -q "${HOOK_GIT}config${HOOK_END}.*\bagent\.autonomous\b" &&
  ! printf '%s' "$HOOK_BARE" | rg -q '\s--get\b' &&
  hook_deny 'Only the user sets agent.autonomous.'

match=$(printf '%s' "$HOOK_BARE" | rg -o "${HOOK_GIT}(?:commit|merge|revert|cherry-pick|am)${HOOK_END}" | head -n 1)
[ -n "$match" ] || exit 0

dir=$(printf '%s' "$match" | rg -o -r '$1' '\s-C\s+(\S+)' | head -n 1)
dir=${dir/#\~/$HOME}
case "$dir" in '') dir=$HOOK_DIR ;; /*) ;; *) dir=$HOOK_DIR/$dir ;; esac

[ "$(git -C "$dir" config --get agent.autonomous 2>/dev/null)" = true ] && exit 0
hook_deny 'Agent commits are off in this repo. Tell the user the work is ready so they commit it.'

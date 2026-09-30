#!/usr/bin/env bash
# gate agent commits on `git config eric-agent.commit`: off (default), ask, branch (not main or master), or on.
# only the user sets eric-agent keys, so agents may not write them
set -u
source "$(dirname "$0")/lib.sh"

hook_require rg jq git awk
hook_read_command
hook_command_dir
hook_bare_command

# each config segment naming an eric-agent key must itself be a read
printf '%s' "$HOOK_BARE" | rg -o "${HOOK_GIT}config${HOOK_END}[^;&|]*\beric-agent\b[^;&|]*" |
  rg -qv '\s(?:--get|--get-regexp|get)\s' &&
  hook_deny 'Only the user sets eric-agent keys.'

match=$(printf '%s' "$HOOK_BARE" | rg -o "${HOOK_GIT}(?:commit|merge|revert|cherry-pick|am)${HOOK_END}" | head -n 1)
[ -n "$match" ] || exit 0

dir=$(printf '%s' "$match" | rg -o -r '$1' '\s-C\s+(\S+)' | head -n 1)
dir=${dir/#\~/$HOME}
case "$dir" in '') dir=$HOOK_DIR ;; /*) ;; *) dir=$HOOK_DIR/$dir ;; esac

case "$(git -C "$dir" config --get eric-agent.commit 2>/dev/null)" in
on) exit 0 ;;
branch)
  case "$(git -C "$dir" symbolic-ref --short -q HEAD)" in
  main | master | '') hook_deny 'Agent commits are allowed only on a feature branch in this repo. Create one, or tell the user the work is ready.' ;;
  esac
  exit 0
  ;;
ask)
  # codex runs a hook's ask as allow, so deny there
  printf '%s' "$HOOK_INPUT" | jq -e '.transcript_path // "" | contains("/.codex/")' >/dev/null &&
    hook_deny 'Agent commits need approval in this repo, and Codex cannot prompt. Tell the user the work is ready so they commit it.'
  hook_ask 'Agent commits need approval in this repo. Approve this commit, or deny it and commit yourself.'
  ;;
esac
hook_deny 'Agent commits are off in this repo. Tell the user the work is ready so they commit it.'

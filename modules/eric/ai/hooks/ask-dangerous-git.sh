#!/usr/bin/env bash
# prompt before git commands that rewrite history, discard uncommitted work, or touch a
# remote. asks rather than denies, so anything genuinely wanted is one confirmation away.
set -u
source "$(dirname "$0")/lib.sh"

hook_require rg jq awk
hook_read_command
hook_bare_command

patterns=(
  "push$HOOK_END"
  "rebase$HOOK_END"
  "reset$HOOK_END"
  'clean\s+-[a-zA-Z]*f'
  'branch\s+.*-D\b'
  'checkout\s+\.(\s|$)'
  'restore\s+\.(\s|$)'
  "filter-branch$HOOK_END"
  "reflog\\s+expire$HOOK_END"
)

for p in "${patterns[@]}"; do
  printf '%s' "$HOOK_BARE" | rg -q "$HOOK_GIT$p" || continue
  hook_ask 'This git command rewrites history, discards uncommitted work, or affects a remote. Approve it, or run it yourself.'
done

exit 0

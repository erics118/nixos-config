#!/usr/bin/env bash
# prompt before git commands that rewrite history or discard uncommitted work.
# asks rather than denies, so anything genuinely wanted is one confirmation away.
set -u
source "$(dirname "$0")/lib.sh"

hook_require rg jq awk
hook_read_command
hook_bare_command

patterns=(
  "rebase$HOOK_END"
  "reset$HOOK_END"
  'clean\s+-[a-zA-Z]*f'
  'branch\s+.*(?:-D\b|(?:-d|--delete)\b.*(?:-f|--force)\b|(?:-f|--force)\b.*(?:-d|--delete)\b)'
  'checkout\s+(?:\S+\s+)?(?:--\s+)?\.(\s|$)'
  'restore\s+(?:--\s+)?\.(\s|$)'
  "filter-branch$HOOK_END"
  "reflog\\s+expire$HOOK_END"
)

for p in "${patterns[@]}"; do
  printf '%s' "$HOOK_BARE" | rg -q "$HOOK_GIT$p" || continue
  hook_ask 'This git command rewrites history or discards uncommitted work. Approve it, or run it yourself.'
done

exit 0

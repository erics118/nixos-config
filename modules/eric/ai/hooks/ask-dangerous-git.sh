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
  'clean\s+(?:-\S+\s+)*(?:-[a-zA-Z]*f|--force)'
  "stash\\s+(?:drop|clear)$HOOK_END"
  "checkout\\s+(?:[^;&|]*\\s)?(?:-f|-B|--force)$HOOK_END"
  "switch\\s+(?:[^;&|]*\\s)?(?:-f|-C|--force|--force-create|--discard-changes)$HOOK_END"
  "worktree\\s+remove\\s+(?:[^;&|]*\\s)?(?:-f|--force)$HOOK_END"
  'branch\s+.*(?:-D\b|(?:-d|--delete)\b.*(?:-f|--force)\b|(?:-f|--force)\b.*(?:-d|--delete)\b)'
  'checkout\s+(?:\S+\s+)?(?:--\s+)?\.(\s|$)'
  'checkout\s+(?:[^;&|]*\s)?--\s+\S'
  "filter-branch$HOOK_END"
  "reflog\\s+expire$HOOK_END"
)

reason='This git command rewrites history or discards uncommitted work. Approve it, or run it yourself.'
for p in "${patterns[@]}"; do
  printf '%s' "$HOOK_BARE" | rg -q "$HOOK_GIT$p" || continue
  hook_ask "$reason"
done

# restore discards worktree changes unless it only unstages with --staged and no --worktree
while IFS= read -r seg; do
  printf '%s' "$seg" | rg -q '\s(?:--staged|-[a-zA-Z]*S)' &&
    ! printf '%s' "$seg" | rg -q '\s(?:--worktree|-[a-zA-Z]*W)' && continue
  hook_ask "$reason"
done < <(printf '%s' "$HOOK_BARE" | rg -o "${HOOK_GIT}restore${HOOK_END}[^;&|]*")

exit 0

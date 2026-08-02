#!/usr/bin/env bash
# prompt before git commands that rewrite history, discard uncommitted work, or touch a
# remote. asks rather than denies, so anything genuinely wanted is one confirmation away.
set -u
source "$HOME/.claude/hooks/lib.sh"

hook_read_command

patterns=(
  '\bgit\s+push\b'
  '\bgit\s+rebase\b'
  '\bgit\s+reset\s+--hard\b'
  '\bgit\s+clean\s+-[a-zA-Z]*f'
  '\bgit\s+branch\s+.*-D\b'
  '\bgit\s+checkout\s+\.(\s|$)'
  '\bgit\s+restore\s+\.(\s|$)'
  '\bgit\s+filter-branch\b'
  '\bgit\s+reflog\s+expire\b'
)

for p in "${patterns[@]}"; do
  printf '%s' "$HOOK_COMMAND" | rg -q "$p" || continue
  hook_ask 'This git command rewrites history, discards uncommitted work, or affects a remote. Approve it, or run it yourself.'
done

exit 0

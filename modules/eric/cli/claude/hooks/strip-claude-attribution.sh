#!/usr/bin/env bash
# strip claude attribution trailers from git commit / gh pr commands before
# they run. the system prompt hardcodes Co-Authored-By and settings do not
# reliably remove it (anthropics/claude-code#4287, #7543), so enforce it here.
set -u
source "$HOME/.claude/hooks/lib.sh"

hook_read_command

printf '%s' "$HOOK_COMMAND" | rg -q '\bgit commit|\bgh pr (create|edit)' || exit 0
printf '%s' "$HOOK_COMMAND" | rg -qi '(co-authored-by|assisted-by):.*(claude|anthropic)|generated with.*claude' || exit 0

stripped=$(printf '%s' "$HOOK_COMMAND" | jq -Rrs '
  gsub("[^\n\"]*([Cc]o-[Aa]uthored-[Bb]y|[Aa]ssisted-[Bb]y):[^\n\"]*([Cc]laude|[Aa]nthropic)[^\n\"]*\n?"; "")
  | gsub("[^\n\"]*[Gg]enerated with[^\n\"]*[Cc]laude[^\n\"]*\n?"; "")
')

hook_update_command "$stripped"

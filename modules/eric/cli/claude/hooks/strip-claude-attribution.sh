#!/usr/bin/env bash
# strip claude attribution trailers from git commit / gh pr commands before
# they run. the system prompt hardcodes Co-Authored-By and settings do not
# reliably remove it (anthropics/claude-code#4287, #7543), so enforce it here.
set -u

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$cmd" ] || exit 0

printf '%s' "$cmd" | grep -Eq 'git commit|gh pr (create|edit)' || exit 0
printf '%s' "$cmd" | grep -Eiq 'co-authored-by:.*(claude|anthropic)|generated with.*claude' || exit 0

printf '%s' "$input" | jq -c '
  .tool_input as $ti
  | ($ti.command
     | gsub("[^\n\"]*[Cc]o-[Aa]uthored-[Bb]y:[^\n\"]*([Cc]laude|[Aa]nthropic)[^\n\"]*\n?"; "")
     | gsub("[^\n\"]*[Gg]enerated with[^\n\"]*[Cc]laude[^\n\"]*\n?"; "")
    ) as $c
  | {hookSpecificOutput:{hookEventName:"PreToolUse", updatedInput:($ti | .command=$c)}}'

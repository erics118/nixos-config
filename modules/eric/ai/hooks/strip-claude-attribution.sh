#!/usr/bin/env bash
# strip claude attribution trailers from git commit commands before they run.
# the system prompt hardcodes Co-Authored-By and settings do not reliably remove it (anthropics/claude-code#4287, #7543), so enforce it here.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
source "$(dirname "$0")/lib.sh"

hook_require rg jq shfmt
hook_read_command
hook_parse_command

hook_any 'git | .[0] == "commit"' || exit 0
printf '%s' "$HOOK_COMMAND" | rg -qi '(co-authored-by|assisted-by):.*(claude|anthropic)|generated with.*claude|claude-session:' || exit 0

stripped=$(printf '%s' "$HOOK_COMMAND" | jq -Rrs '
  gsub("[^\n\"\u0027]*(co-authored-by|assisted-by):[^\n\"\u0027]*(claude|anthropic)[^\n\"\u0027]*\n?"; ""; "i")
  | gsub("[^\n\"\u0027]*generated with[^\n\"\u0027]*claude[^\n\"\u0027]*\n?"; ""; "i")
  | gsub("[^\n\"\u0027]*claude-session:[^\n\"\u0027]*\n?"; ""; "i")
')

hook_update_command "$stripped"

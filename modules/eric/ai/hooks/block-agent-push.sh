#!/usr/bin/env bash
# block agent pushes and GitHub writes in every repo. the user pushes and opens PRs
set -u
source "$(dirname "$0")/lib.sh"

hook_require rg jq awk
hook_read_command
hook_bare_command

GH="${HOOK_PREFIX}gh\\s+"

printf '%s' "$HOOK_BARE" | rg -q "${HOOK_GIT}push${HOOK_END}" &&
  hook_deny 'Agents never push. Tell the user the work is ready so they push it.'

# gh is read-only: allow only known reads, so new write commands are denied too
while read -r group sub; do
  case "$group $sub" in
  'api '* | 'search '* | 'status ' | 'repo clone' | *' view' | *' list' | *' status' | *' diff' | *' checks') continue ;;
  esac
  hook_deny "Agents use gh read-only, and gh $group $sub is not a known read. Tell the user what to run."
done < <(printf '%s' "$HOOK_BARE" | rg -o -r '$1 $2' "${GH}(\S+)(?:\s+([^\s;&|)]+))?")

printf '%s' "$HOOK_BARE" | rg -q "${GH}[^;&|]*--show-token" &&
  hook_deny 'Agents never print the GitHub token.'

# gh api writes: a non-GET method, or fields, which make gh default to POST
printf '%s' "$HOOK_BARE" | rg -o "${GH}api\s[^;&|]*" |
  rg -qi '\s(?:-X\s*|--method[\s=]\s*)(?:POST|PUT|PATCH|DELETE)\b|\s(?:-f|-F|--field|--raw-field|--input)[\s=]' &&
  hook_deny 'Agents never write to GitHub through gh api. Use read-only gh api calls, or tell the user what to run.'

exit 0

#!/usr/bin/env bash
# block shell edits of git-tracked files: sed/perl in place, scripts that write files, and
# redirects or tee onto a tracked file. these skip the edit tool, so the change never
# shows as a diff and /rewind cannot undo it
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
source "$(dirname "$0")/lib.sh"

hook_require rg jq git shfmt
hook_read_command
hook_parse_command
hook_command_dir
reason='is tracked by git. Change it with the edit tool so the change shows as a reviewable diff.'

# sed or perl in place: check that command's operands
while IFS= read -r w; do
  hook_tracked "$w" && hook_deny "$w $reason"
done < <(hook_each '
  select((tool == "sed" and any(.argv[1:][]; test("^-(-in-place|[a-zA-Z]*i)"))) or
    (tool == "perl" and any(.argv[1:][]; test("^-[a-z]*i")))) |
  .argv[1:][] | select(startswith("-") | not)
')

# a script that writes files: check the literal path each write names. when a write
# targets a variable instead, check every quoted path the script names
if printf '%s' "$HOOK_COMMAND" | rg -q '\b(python3?|node|ruby)\b' &&
  printf '%s' "$HOOK_COMMAND" | rg -q '(write_text|write_bytes|writeFileSync|open\([^)]*[\x27"][wa]\+?[\x27"])'; then
  literal=$(
    printf '%s' "$HOOK_COMMAND" | rg -o -r '$1' 'Path\(\s*[\x27"]([^\x27"]+)[\x27"]\s*\)\.write_(?:text|bytes)'
    printf '%s' "$HOOK_COMMAND" | rg -o -r '$1' 'open\(\s*[\x27"]([^\x27"]+)[\x27"]\s*,\s*[\x27"][wa]'
    printf '%s' "$HOOK_COMMAND" | rg -o -r '$1' 'writeFileSync\(\s*[\x27"]([^\x27"]+)[\x27"]'
  )
  writes=$(printf '%s' "$HOOK_COMMAND" | rg -o '(write_text|write_bytes|writeFileSync|open\([^)]*[\x27"][wa]\+?[\x27"])' | wc -l)
  if [ -n "$literal" ] && [ "$(printf '%s\n' "$literal" | wc -l)" -ge "$writes" ]; then
    candidates=$literal
  else
    candidates=$(
      printf '%s' "$HOOK_COMMAND" | rg -o -r '$1' "'([^'\s]+)'"
      printf '%s' "$HOOK_COMMAND" | rg -o -r '$1' '"([^"\s]+)"'
    )
  fi
  while IFS= read -r c; do
    hook_tracked "$c" && hook_deny "$c $reason"
  done <<<"$candidates"
fi

# ... > file, ... >> file, or tee file
while IFS= read -r f; do
  case "$f" in /dev/* | '') continue ;; esac
  hook_tracked "$f" && hook_deny "$f $reason"
done < <(hook_each 'writes')

exit 0

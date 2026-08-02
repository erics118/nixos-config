#!/usr/bin/env bash
# block `find` commands rooted at / (or other filesystem-wide roots): scanning the
# whole filesystem is slow, can hang on network/special mounts, and is never what's needed.
set -u
source "$HOME/.claude/hooks/lib.sh"

hook_require rg jq
hook_read_command

# match `find` as a command word, followed by a root path of / (not ./ or a subpath)
printf '%s' "$HOOK_COMMAND" | rg -q '\bfind\s+/(\s|$)' || exit 0

hook_deny 'find rooted at / scans the whole filesystem. Search from a specific directory (e.g. `find . -name ...` or `find /path/to/dir ...`) instead.'

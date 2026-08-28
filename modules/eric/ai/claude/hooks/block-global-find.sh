#!/usr/bin/env bash
# block `find` commands rooted at / (or other filesystem-wide roots): scanning the
# whole filesystem is slow, can hang on network/special mounts, and is never what's needed.
set -u
source "$HOME/.claude/hooks/lib.sh"

hook_require rg jq
hook_read_command

# match `find` as a command word, optional leading flags, then a filesystem-wide root as
# the first path arg: / , /nix (any depth), whole $HOME / ~ / /home/<user>, or a huge/
# hang-prone system root. Bounded subpaths (find . , find /home/eric/dev , find ~/proj) pass.
printf '%s' "$HOOK_COMMAND" | rg -q '\bfind\s+(-[A-Za-z]+\s+)*(/(\s|$)|~/?(\s|$)|\$\{?HOME\}?/?(\s|$)|/nix(/|\s|$)|/(home|Users)(/[^/[:space:]]+)?/?(\s|$)|/(usr|var|proc|sys)(\s|$))' || exit 0

hook_deny 'find rooted at a filesystem-wide directory (/, /nix, ~, $HOME, /home/<user>, /Users/<user>, or a system root) scans far too much and can hang on special mounts. Search from a specific directory instead (e.g. `find . -name ...` or `find /path/to/project ...`).'

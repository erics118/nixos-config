#!/usr/bin/env bash
# block `find`, `fd`, `rg`, and `grep` commands rooted at / (or other filesystem-wide roots): scanning the
# whole filesystem is slow, can hang on network/special mounts, and is never what's needed.
set -u
source "$(dirname "$0")/lib.sh"

hook_require rg jq awk
hook_read_command
hook_bare_command

# the tool in command position: after a separator, env assignments, `command`, or a dir prefix
cmd='(?:^|[;&|(]\s*)(?:\w+=\S*\s+)*(?:command\s+)?(?:\S*/)?'
# a filesystem-wide root: / , /nix (any depth), whole $HOME / ~ / /home/<user>, or a huge/
# hang-prone system root. bounded subpaths (. , /home/eric/dev , ~/proj) pass
root='(?:/|~/?|\$\{?HOME\}?/?|/nix(?:/[^\s;&|)`]*)?|/(?:home|Users)(?:/[^/\s;&|)`]+)?/?|/(?:usr|var|proc|sys|System|Library|private|Volumes)/?)(?:\s|$|[;&|)`])'
word='[^\s;&|]+'
# find takes the root as its first path arg after optional flags.
# fd, rg, and grep take their first positional as the pattern, so the root is a later
# positional, or the value of a path flag
printf '%s' "$HOOK_BARE" | rg -q \
  -e "${cmd}find\\s+(?:-[A-Za-z]+\\s+)*${root}" \
  -e "${cmd}(?:fd|rg|grep)\\s+(?:-${word}\\s+)*[^-\\s;&|][^\\s;&|]*\\s+(?:${word}\\s+)*${root}" \
  -e "${cmd}(?:fd|rg|grep)\\s+(?:${word}\\s+)*(?:--files\\s+(?:${word}\\s+)*|--(?:base-directory|search-path)[\\s=])${root}" ||
  exit 0

hook_deny 'find, fd, rg, or grep rooted at a filesystem-wide directory (/, /nix, ~, $HOME, /home/<user>, /Users/<user>, or a system root) scans far too much and can hang on special mounts. Search from a specific directory instead (e.g. `fd <pattern> .` or `fd <pattern> /path/to/project`).'

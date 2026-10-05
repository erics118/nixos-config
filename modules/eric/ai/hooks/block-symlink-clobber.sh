#!/usr/bin/env bash
# block Bash mv/cp/redirect/tee that would overwrite a path that is currently a symlink:
# mv/redirect replace the symlink itself instead of writing through it, silently
# detaching nix-managed config (out-of-store symlinks) from its real source.
set -u
source "$(dirname "$0")/lib.sh"

hook_require rg jq realpath awk
hook_read_command
hook_bare_command

# figure out which path this command would overwrite, based on its shape
# mv/cp src dst, or tee file: destination is the command's last word. only in command position,
# so that a mention like `rg -n cp somefile` is not read as a copy
# one command per line
# the last word skips trailing redirects like 2>/dev/null
segs=$(printf '%s' "$HOOK_BARE" | tr ';&|' '\n')
last='\s([^\s>]+)(?:\s*\d*>{1,2}\s*\S*)*\s*$'
target=$(printf '%s' "$segs" | rg -o -r '$1' "^\\s*(?:mv|cp|tee)\\b.*?$last")
# in-place editors write a temp file and rename over the link: sed -i, perl -i, truncate
[ -n "$target" ] || target=$(printf '%s' "$segs" | rg -o -r '$1' "\\b(?:(?:sed|perl)\\b.*\\s-i|truncate)\\b.*?$last")

# check every candidate, since a trailing 2>/dev/null must not shadow the real redirect target
while IFS= read -r candidate; do
  # fd dupes like 2>&1 and device sinks are not files we can clobber
  case "$candidate" in '&'* | /dev/*) continue ;; esac
  # expand a literal leading ~ or $HOME without eval (never execute embedded command substitutions)
  candidate="${candidate/#\~/$HOME}"
  candidate="${candidate//\$HOME/$HOME}"
  [ -L "$candidate" ] || continue

  real=$(realpath "$candidate" 2>/dev/null)
  hook_deny "$candidate is a symlink (-> $real). mv/cp/redirect would replace the link itself, detaching it from its real source. Edit $real directly instead."
done < <(
  [ -n "$target" ] && printf '%s\n' "$target"
  # ... > file or ... >> file
  printf '%s' "$HOOK_BARE" | rg -o -r '$1' '>{1,2}\s*(\S+)'
)

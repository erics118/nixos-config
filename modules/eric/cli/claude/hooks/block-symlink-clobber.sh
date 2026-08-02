#!/usr/bin/env bash
# block Bash mv/cp/redirect/tee that would overwrite a path that is currently a symlink:
# mv/redirect replace the symlink itself instead of writing through it, silently
# detaching nix-managed config (out-of-store symlinks) from its real source.
set -u
source "$HOME/.claude/hooks/lib.sh"

hook_read_command

# figure out which path this command would overwrite, based on its shape
# mv/cp src dst, or tee file: destination is the last word
target=$(printf '%s' "$HOOK_COMMAND" | rg -o -r '$1' '\b(?:mv|cp|tee)\b.*\s(\S+)$')
# in-place editors write a temp file and rename over the link: sed -i, perl -i, truncate
[ -n "$target" ] || target=$(printf '%s' "$HOOK_COMMAND" | rg -o -r '$1' '\b(?:(?:sed|perl)\b[^;|]*\s-i|truncate)\b.*\s(\S+)$')
# ... > file or ... >> file (last redirect target wins)
[ -n "$target" ] || target=$(printf '%s' "$HOOK_COMMAND" | rg -o -r '$1' '>{1,2}\s*(\S+)' | tail -1)

[ -n "$target" ] || exit 0

# expand a literal leading ~ or $HOME without eval (never execute embedded command substitutions)
target="${target/#\~/$HOME}"
target="${target//\$HOME/$HOME}"
[ -L "$target" ] || exit 0

real=$(realpath "$target" 2>/dev/null)
hook_deny "$target is a symlink (-> $real). mv/cp/redirect would replace the link itself, detaching it from its real source. Edit $real directly instead."

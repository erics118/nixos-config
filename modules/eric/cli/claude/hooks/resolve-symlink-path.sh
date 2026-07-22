#!/usr/bin/env bash
# if a Write/Edit target is a symlink, rewrite the tool input to its real path
# so the tool doesn't refuse to write through it. handles nix-managed ~/.claude
# and dotfile symlinks that resolve back into a repo (out-of-store).
set -u
source "$HOME/.claude/hooks/lib.sh"

hook_read_file_path

[ -L "$HOOK_FILE" ] || exit 0
real=$(realpath "$HOOK_FILE" 2>/dev/null) || exit 0
[ -n "$real" ] && [ "$real" != "$HOOK_FILE" ] || exit 0

# only rewrite when the symlink resolves back into a config location
case "$real" in
"$HOME/nixos-config"/*) ;;
"$HOME/.flake"/*) ;;
"$HOME/.config"/*) ;;
*) exit 0 ;;
esac

hook_update_file_path "$real"

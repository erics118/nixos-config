#!/usr/bin/env bash
# if a Read/Write/Edit target is a symlink, rewrite the tool input to its real path.
# Write/Edit: so the tool doesn't refuse to write through the symlink.
# Read: so read-state is tracked against the same real path, else the first Write
# after a Read fails with "file has not been read yet" (paths wouldn't match).
# handles nix-managed ~/.claude and dotfile symlinks that resolve into a repo.
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

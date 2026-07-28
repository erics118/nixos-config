#!/usr/bin/env bash
# steer Claude to the real repo path for nix-managed dotfile symlinks.
# deny the symlink path and hand back the resolved realpath, rather than silently
# rewriting it: a rewrite desyncs the read-gate/receipt tracking (Read stays on the
# symlink, Write moves to the target) and surfaces as "not read yet" / "modified
# since read". deny-and-tell keeps Claude's read and write on the same real path.
set -u
source "$HOME/.claude/hooks/lib.sh"

hook_read_file_path

[ -L "$HOOK_FILE" ] || exit 0
real=$(realpath "$HOOK_FILE" 2>/dev/null) || exit 0
[ -n "$real" ] && [ "$real" != "$HOOK_FILE" ] || exit 0

# only steer when the symlink resolves back into a managed repo location
case "$real" in
"$HOME/nixos-config"/*) ;;
"$HOME/.flake"/*) ;;
"$HOME/.config"/*) ;;
*) exit 0 ;;
esac

hook_deny "That path is a symlink into a nix-managed repo. Read and edit the real path instead: $real"

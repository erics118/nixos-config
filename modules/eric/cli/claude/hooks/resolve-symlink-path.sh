#!/usr/bin/env bash
# if a Write/Edit target is a symlink, rewrite the tool input to its real path
# so the tool doesn't refuse to write through it. handles nix-managed ~/.claude
# and dotfile symlinks that resolve back into a repo (out-of-store).
set -u

input=$(cat)
f=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
[ -n "$f" ] || exit 0
[ -L "$f" ] || exit 0
real=$(realpath "$f" 2>/dev/null) || exit 0
[ -n "$real" ] && [ "$real" != "$f" ] || exit 0

# only rewrite when the symlink resolves back into a config location
case "$real" in
"$HOME/nixos-config"/*) ;;
"$HOME/.flake"/*) ;;
"$HOME/.config"/*) ;;
*) exit 0 ;;
esac

printf '%s' "$input" | jq -c --arg real "$real" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse", updatedInput:(.tool_input | .file_path=$real)}}'

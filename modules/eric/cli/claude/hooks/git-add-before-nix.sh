#!/usr/bin/env bash
# block flake-evaluating commands when untracked .nix files exist: flakes only
# see git-tracked files, so an unstaged new module is silently invisible and the
# change appears to do nothing. tells the model to git add them first.
set -u

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$cmd" ] || exit 0

# only flake-evaluating commands
printf '%s' "$cmd" | grep -Eq 'nix (build|develop|eval|run|fmt|flake (check|show|metadata))|nh (darwin|os) (build|switch)|just (build|switch|check|dev)' || exit 0

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$root/flake.nix" ] || exit 0

untracked=$(cd "$root" && git ls-files --others --exclude-standard -- '*.nix' 2>/dev/null)
[ -n "$untracked" ] || exit 0

files=$(printf '%s' "$untracked" | tr '\n' ' ')
jq -cn --arg files "$files" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"deny",
    permissionDecisionReason:("Untracked .nix files are invisible to flake eval. git add them first: " + $files)}}'

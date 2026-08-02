#!/usr/bin/env bash
# block flake-evaluating commands when untracked .nix files exist: flakes only
# see git-tracked files, so an unstaged new module is silently invisible and the
# change appears to do nothing. tells the model to git add them first.
set -u
source "$HOME/.claude/hooks/lib.sh"

hook_require rg jq git
hook_read_command

# only flake-evaluating commands
printf '%s' "$HOOK_COMMAND" | rg -q '\bnix (build|develop|eval|run|fmt|flake (check|show|metadata))|\bnh (darwin|os) (build|switch)|\bjust (build|switch|check|dev)' || exit 0

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$root/flake.nix" ] || exit 0

untracked=$(cd "$root" && git ls-files --others --exclude-standard -- '*.nix' 2>/dev/null)
[ -n "$untracked" ] || exit 0

files=$(printf '%s' "$untracked" | tr '\n' ' ')
hook_deny "Untracked .nix files are invisible to flake eval. git add them first: $files"

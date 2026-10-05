#!/usr/bin/env bash
# block flake-evaluating commands when untracked files exist: flakes only see
# git-tracked files, so a new module, config file, or skill is silently invisible
# and the change appears to do nothing. tells the model to git add them first.
set -u
source "$(dirname "$0")/lib.sh"

hook_require rg jq git awk
hook_read_command
hook_command_dir
hook_bare_command

# only flake-evaluating commands
printf '%s' "$HOOK_BARE" | rg -q "${HOOK_PREFIX}(?:just\\s+(?:build|switch|check|dev)|(?:nix\\s+(?:build|develop|eval|run|fmt|flake\\s+(?:check|show|metadata))|nh\\s+(?:darwin|os)\\s+(?:build|switch)|darwin-rebuild|nixos-rebuild|home-manager)${HOOK_END})" || exit 0

root=$(git -C "$HOOK_DIR" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$root/flake.nix" ] || exit 0

untracked=$(git -C "$root" ls-files --others --exclude-standard 2>/dev/null)
[ -n "$untracked" ] || exit 0

files=$(printf '%s' "$untracked" | tr '\n' ' ')
hook_deny "Untracked files are invisible to flake eval. git add them first: $files"

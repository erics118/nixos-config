#!/usr/bin/env bash
# shellcheck disable=SC2016
# block flake-evaluating commands when untracked files exist: flakes only see
# git-tracked files, so a new module, config file, or skill is silently invisible
# and the change appears to do nothing. tells the model to git add them first.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
source "$(dirname "$0")/lib.sh"

hook_require jq git shfmt
hook_read_command
hook_parse_command
hook_command_dir

# only flake-evaluating commands
hook_any '
  .argv as $a | tool as $t |
    ($t == "just" and ($a[1] | IN("build", "switch", "check", "dev"))) or
    ($t == "nix" and (($a[1] | IN("build", "develop", "eval", "run", "fmt")) or ($a[1] == "flake" and ($a[2] | IN("check", "show", "metadata"))))) or
    ($t == "nh" and ($a[1] | IN("darwin", "os")) and ($a[2] | IN("build", "switch"))) or
    ($t | IN("darwin-rebuild", "nixos-rebuild", "home-manager"))
' || exit 0

root=$(git -C "$HOOK_DIR" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$root/flake.nix" ] || exit 0

untracked=$(git -C "$root" ls-files --others --exclude-standard 2>/dev/null)
[ -n "$untracked" ] || exit 0

files=$(printf '%s' "$untracked" | tr '\n' ' ')
hook_deny "Untracked files are invisible to flake eval. git add them first: $files"

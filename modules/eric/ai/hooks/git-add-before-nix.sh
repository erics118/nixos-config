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

flake=0
hook_any '
  .argv as $a | tool as $t |
    ($t == "nix" and (($a[1] | IN("build", "develop", "eval", "run", "fmt")) or ($a[1] == "flake" and ($a[2] | IN("check", "show", "metadata"))))) or
    ($t == "nh" and ($a[1] | IN("darwin", "os")) and ($a[2] | IN("build", "switch"))) or
    ($t | IN("darwin-rebuild", "nixos-rebuild", "home-manager"))
' && flake=1

# a just recipe counts only when its dry run calls nix, since many repos with a flake use just for other builds
# a dry run that fails falls back to the recipe name, so an unreadable justfile still blocks
if [ "$flake" -eq 0 ]; then
  while IFS= read -r line; do
    recipe=${line#R:}
    if out=$(cd "$HOOK_DIR" && just --dry-run ${recipe:+"$recipe"} 2>&1); then
      printf '%s' "$out" | grep -Eqw 'nix|nh|darwin-rebuild|nixos-rebuild|home-manager' && flake=1
    else
      case "$recipe" in build | switch | check | dev) flake=1 ;; esac
    fi
  done < <(hook_each 'select(tool == "just") | "R:" + ([.argv[1:][] | select(startswith("-") | not)][0] // "")')
fi
[ "$flake" -eq 1 ] || exit 0

root=$(git -C "$HOOK_DIR" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$root/flake.nix" ] || exit 0

untracked=$(git -C "$root" ls-files --others --exclude-standard 2>/dev/null)
[ -n "$untracked" ] || exit 0

files=$(printf '%s' "$untracked" | tr '\n' ' ')
hook_deny "Untracked files are invisible to flake eval. git add them first: $files"

#!/usr/bin/env bash
# make a fresh scratch folder for one task and print its path (see the .eric/ rules in AGENTS-global.md)
# usage: new-scratch.sh TOPIC
# a taken name gets -2, -3, and so on, so no two tasks or agents share a folder
set -euo pipefail

topic=${1:?usage: new-scratch.sh TOPIC}

# the main repo's root, also from a worktree, else home.
# a submodule's common dir sits under .git/modules, so it uses its own top folder
root=$HOME
if common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
  if [[ ${common##*/} == .git ]]; then
    root=${common%/.git}
  else
    root=$(git rev-parse --show-toplevel)
  fi
fi

mkdir -p "$root/.eric/scratch"
base=$root/.eric/scratch/$(date +%F)-$topic
dir=$base
n=1
# mkdir without -p fails on a taken name
until mkdir "$dir" 2>/dev/null; do
  [[ -e $dir ]] || {
    echo "new-scratch: cannot create $dir" >&2
    exit 1
  }
  n=$((n + 1))
  dir=$base-$n
done
printf '%s\n' "$dir"

#!/usr/bin/env bash
# make a git worktree for one task and print its path (see the .eric/ rules in AGENTS-global.md)
# usage: new-worktree.sh BRANCH [BASE]
# makes BRANCH from BASE (default HEAD) in the main repo's .eric/worktrees, named eric-agent-scratch- and the branch's last part
set -euo pipefail

branch=${1:?usage: new-worktree.sh BRANCH [BASE]}
base=${2:-HEAD}

# the main repo's root, also from inside a worktree
common=$(git rev-parse --path-format=absolute --git-common-dir)
if [[ ${common##*/} != .git ]]; then
  echo "new-worktree: run it from the main repo or one of its worktrees, not a submodule" >&2
  exit 1
fi
root=${common%/.git}
name=${branch##*/}
dir=$root/.eric/worktrees/eric-agent-scratch-${name#eric-agent-scratch-}

git worktree add -q -b "$branch" "$dir" "$base" >&2

# check out the submodules the main checkout has, a level at a time, borrowing its objects
init_submodules() {
  local wt=$1 main=$2 path
  [[ -f $wt/.gitmodules ]] || return 0
  while read -r -u 3 _ path; do
    [[ -e $main/$path/.git ]] || continue
    git -C "$wt" submodule update -q --init --reference "$main/$path" -- "$path" >&2
    init_submodules "$wt/$path" "$main/$path"
  done 3< <(git config -f "$wt/.gitmodules" --get-regexp '\.path$')
}
init_submodules "$dir" "$root"

printf '%s\n' "$dir"

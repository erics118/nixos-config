#!/usr/bin/env bash
# print the session name sesh gives a folder, which rext and mvproj name sessions by
# in sesh's order (namer/namer.go): a course by its path below ~/dev/latex/<term> (sesh.nix), a repo and subpath, or the folder
# then . and : and each run of whitespace become _ (namer/convert.go)

set -euo pipefail

usage="Usage: project-name PATH"
case ${1-} in
-h | --help)
  echo "$usage"
  exit
  ;;
esac
[[ $# -eq 1 ]] || {
  echo "$usage" >&2
  exit 1
}

course='^~/dev/latex/[^/]+/(.+)$'
path=$(realpath -m -- "${1/#\~/$HOME}")
# a folder that doesn't exist yet, such as mvproj --dry-run's target, is named from its nearest existing parent
base=$path rest=
while [[ ! -d $base ]]; do
  rest=/${base##*/}$rest
  base=${base%/*}
  base=${base:-/}
done
if [[ $path == "$HOME"/* && "~${path#"$HOME"}" =~ $course ]]; then
  name=${BASH_REMATCH[1]}
elif top=$(git -C "$base" rev-parse --show-toplevel 2>/dev/null); then
  # git gives the subpath as the disk spells it, which a path typed in another case would not match on macOS
  sub=$(git -C "$base" rev-parse --show-prefix)
  # sesh names from the main worktree, so a linked worktree inside it gets its path from there (namer/git.go).
  # one outside it is named after itself, where sesh would put the full path in the name
  main=$(git -C "$base" worktree list --porcelain | sed -n '1s/^worktree //p')
  [[ $top == "$main"/* ]] || main=$top
  name=${main##*/}${top#"$main"}${sub:+/${sub%/}}$rest
else
  name=${path##*/}
fi

read -ra words <<<"${name//[.:]/_}"
IFS=_
printf '%s\n' "${words[*]}"

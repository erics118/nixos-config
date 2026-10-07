#!/usr/bin/env bash
set -euo pipefail
[ $# -eq 3 ] || {
  echo "usage: review-package.sh PLAN_FILE BASE HEAD" >&2
  exit 2
}
plan=$1 base=$2 head=$3
git merge-base --is-ancestor "$base" "$head" || {
  echo "HEAD is not a descendant of BASE: $base..$head" >&2
  exit 3
}
[ "$(git rev-list --count "$base..$head")" -gt 0 ] || {
  echo "empty range: $base..$head" >&2
  exit 3
}
dir="$(git rev-parse --show-toplevel)/.eric/plans/$(basename "$plan" .md)"
mkdir -p "$dir"
printf '*\n' >"$dir/.gitignore"
out="$dir/review-$(git rev-parse --short "$base")..$(git rev-parse --short "$head").diff"
{
  echo "## Commits"
  git log --oneline "$base..$head"
  echo
  echo "## Files changed"
  git diff --stat "$base..$head"
  echo
  echo "## Diff"
  git diff -U10 "$base..$head"
} >"$out"
echo "$out"

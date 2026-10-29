#!/usr/bin/env bash
# fold a finished course repo, with its history, into a folder of the cornell monorepo

set -euo pipefail

die() {
  echo "cornell-archive: $*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: cornell-archive [--dry-run] SOURCE DEST

  Move SOURCE's history under DEST (such as cs3410/a6) in the monorepo,
  add a line for it to the monorepo's README.md, and push.
  SOURCE is a local clone, a git URL, or a GitHub repo (name or owner/name).
  A GitHub repo SOURCE is archived after the push.
  The monorepo is \$CORNELL_REPO, a GitHub repo or a path, default erics118/cornell.

  --dry-run  build the merge in a temp folder and print it, without pushing or archiving
EOF
}

dry=
case ${1-} in
-h | --help)
  usage
  exit
  ;;
--dry-run)
  dry=1
  shift
  ;;
esac
[[ $# -eq 2 ]] || {
  usage >&2
  exit 1
}
source=$1
dest=${2%/}
[[ $dest =~ ^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$ ]] || die "bad DEST: $dest"

# prints a cloneable URL for a path, URL, or GitHub repo name
resolve() {
  if [[ -d $1 ]]; then
    realpath -- "$1"
  elif [[ $1 == *://* || $1 == *@*:* ]]; then
    echo "$1"
  else
    gh repo view "$1" --json sshUrl -q .sshUrl
  fi
}

gh_source=
desc=
label=$source
if [[ -d $source ]]; then
  [[ -z $(git -C "$source" status --porcelain) ]] || die "uncommitted changes in $source"
  label=$(git -C "$source" remote get-url origin 2>/dev/null || realpath -- "$source")
elif [[ $source != *://* && $source != *@*:* ]]; then
  gh_source=$(gh repo view "$source" --json nameWithOwner -q .nameWithOwner) || die "no GitHub repo: $source"
  label=$gh_source
  desc=$(gh repo view "$gh_source" --json description -q .description)
fi
src_url=$(resolve "$source")
mono=${CORNELL_REPO:-erics118/cornell}
mono_url=$(resolve "$mono") || die "no monorepo $mono, make it with: gh repo create cornell --private"

tmp=$(mktemp -d)
[[ -n $dry ]] || trap 'rm -rf -- "$tmp"' EXIT

git clone -q -- "$mono_url" "$tmp/mono"
[[ ! -e $tmp/mono/$dest ]] || die "$dest already exists in $mono"
# filter-repo rewrites only a fresh clone, and --no-local makes a local source one
git clone -q --no-local -- "$src_url" "$tmp/src"
git -C "$tmp/src" filter-repo --quiet --to-subdirectory-filter "$dest"

cd -- "$tmp/mono"
if ! git rev-parse -q --verify HEAD >/dev/null; then
  printf '# cornell\n\nfinished coursework, one folder per assignment. each came from:\n\n' >README.md
  git add README.md
  git commit -q -m "readme"
fi
git fetch -q "$tmp/src" HEAD
git merge -q --allow-unrelated-histories --no-edit -m "$dest: add from $label" FETCH_HEAD
printf -- "- \`%s\`: %s%s\n" "$dest" "$label" "${desc:+ ($desc)}" >>README.md
git add README.md
git commit -q -m "readme: $dest"

if [[ -n $dry ]]; then
  echo "dry run, nothing pushed: $tmp/mono"
  exit
fi
git push -q origin HEAD
echo "added $dest to $mono"
if [[ -n $gh_source ]]; then
  gh repo archive "$gh_source" --yes
fi

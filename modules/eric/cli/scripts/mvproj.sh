#!/usr/bin/env bash
# move a project folder and carry its claude and pi history, memory, and tmux session along

set -euo pipefail

die() {
  echo "mvproj: $*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: mvproj [--dry-run] [OLD] NEW

  Move the folder OLD to NEW, then carry along what is keyed by its path:
  claude sessions and memory, pi sessions and project memory, and a tmux
  session named after the folder. Subfolders of OLD are covered too.
  OLD defaults to the current folder.
  A NEW without a / is a name, and renames OLD in place.
  For a folder directly in ~/dev/scratch, the name moves it to ~/dev/NEW instead.
  Refuses while any process other than the calling shell runs inside OLD.

  --dry-run  print every move and rewrite without doing them
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
[[ $# -eq 1 ]] && set -- . "$1"
[[ $# -eq 2 ]] || {
  usage >&2
  exit 1
}

[[ -d $1 ]] || die "not a folder: $1"
old=$(cd "$1" && pwd -P)
dest=$2
if [[ $dest != */* ]]; then
  parent=$(dirname "$old")
  # scratch in zsh/init.zsh makes its folders here
  # naming one promotes it to a project in ~/dev
  [[ $parent != "$HOME/dev/scratch" ]] || parent=$HOME/dev
  dest=$parent/$dest
fi
[[ ! -e $dest && ! -L $dest ]] || die "already exists: $dest"
[[ -d $(dirname "$dest") ]] || die "parent folder missing: $(dirname "$dest")"
new=$(cd "$(dirname "$dest")" && pwd -P)/$(basename "$dest")
[[ $new != "$old"/* ]] || die "cannot move a folder into itself"
# both paths are matched inside json strings, which escape these characters
[[ $old$new != *[\"\\]* ]] || die 'paths with " or \ are not supported'

# lsof and sed below must not count as processes inside OLD
cd /

run() {
  if [[ -n $dry ]]; then
    echo "$*"
  else
    "$@"
  fi
}

# shells this command runs under may sit in OLD, since their cwd follows the folder
skip=" $$ "
pid=$PPID
while [[ $pid -gt 1 ]]; do
  comm=$(ps -o comm= -p "$pid") || break
  case ${comm##*/} in
  sh | -sh | bash | -bash | zsh | -zsh | fish | -fish) skip+="$pid " ;;
  esac
  pid=$(ps -o ppid= -p "$pid" | tr -d ' ')
done

busy=$(lsof -w -d cwd -Fpcn | awk -v old="$old" -v skip="$skip" '
  /^p/ { pid = substr($0, 2) }
  /^c/ { comm = substr($0, 2) }
  /^n/ {
    path = substr($0, 2)
    if ((path == old || index(path, old "/") == 1) && index(skip, " " pid " ") == 0)
      print "  " pid " " comm " in " path
  }')
[[ -z $busy ]] || die "processes are running inside $old:
$busy"

claude_enc() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }
pi_enc() {
  local p=${1#/}
  printf -- '--%s--' "${p//[\/:]/-}"
}

# the folder a history dir belongs to: one of the cwds its sessions started in that encodes to the dir name.
# prints nothing when no file records one
dir_path() {
  local enc=$1 dir=$2 cwd
  while IFS= read -r cwd; do
    if [[ $("$enc" "$cwd") == "$(basename "$dir")" ]]; then
      printf '%s' "$cwd"
      return
    fi
  done < <(grep -rhoE -m1 '"cwd":"[^"]*"' --include='*.jsonl' "$dir" 2>/dev/null | sort -u | sed 's/^"cwd":"//; s/"$//')
}

# history dirs for OLD and its subfolders, as "olddir<TAB>newdir" lines
plan() {
  local enc=$1 root=$2 exact=$3 sub=$4 dir path
  [[ -d $root ]] || return 0
  # sort -u since pi's subfolder glob also matches the exact dir
  for dir in "$root/$exact" "$root/$sub"*; do
    [[ -d $dir ]] || continue
    path=$(dir_path "$enc" "$dir")
    if [[ -z $path && $dir == "$root/$exact" ]]; then
      path=$old
    fi
    if [[ $path == "$old" || $path == "$old"/* ]]; then
      printf '%s\t%s\n' "$dir" "$root/$("$enc" "$new${path#"$old"}")"
    fi
  done | sort -u
}

claude_root=$HOME/.claude/projects
pi_root=$HOME/.pi/agent/sessions
# claude cuts a dir name past 200 chars to 200 plus a hash, which this script does not reproduce
enc_old=$(claude_enc "$old")
[[ ${#enc_old} -le 200 ]] || die "path too long for claude's folder naming: $old"
claude_moves=$(plan claude_enc "$claude_root" "$enc_old" "$enc_old-")
pi_moves=$(plan pi_enc "$pi_root" "$(pi_enc "$old")" "$(pi_enc "$old" | sed 's/--$/-/')")

while IFS=$'\t' read -r from to; do
  [[ -n $from ]] || continue
  [[ ${#to} -le $((${#claude_root} + 201)) ]] || die "path too long for claude's folder naming: $to"
done <<<"$claude_moves"
while IFS=$'\t' read -r from to; do
  [[ -z $from || ! -e $to ]] || die "history target already exists: $to"
done <<<"$claude_moves
$pi_moves"

old_mem=$HOME/.pi/agent/projects-memory/$(basename "$old")
new_mem=$HOME/.pi/agent/projects-memory/$(basename "$new")
if [[ $old_mem != "$new_mem" && -d $old_mem ]]; then
  [[ ! -e $new_mem ]] || die "pi project memory already exists: $new_mem"
else
  old_mem=
fi

# escape a string for a sed pattern, or for a sed replacement
esc() { printf '%s' "$1" | sed 's/[][\.*^$/]/\\&/g'; }
esc_to() { printf '%s' "$1" | sed 's/[\/&]/\\&/g'; }
# rewrite "FIELD":"FROM" and "FIELD":"FROM/..." to TO in the session files under DIR
replace() {
  local field=$1 from=$2 to=$3 dir=$4 f
  if [[ -n $dry ]]; then
    echo "rewrite $field $from -> $to in $dir"
    return
  fi
  { grep -rlF --include='*.jsonl' "\"$field\":\"$from" "$dir" || true; } | while IFS= read -r f; do
    sed -i "s/\"$field\":\"$(esc "$from")\([\"/]\)/\"$field\":\"$(esc_to "$to")\1/g" "$f"
  done
}

run mv "$old" "$new"

while IFS=$'\t' read -r from to; do
  [[ -n $from ]] || continue
  run mv "$from" "$to"
  replace cwd "$old" "$new" "$to"
done <<<"$claude_moves"

while IFS=$'\t' read -r from to; do
  [[ -n $from ]] || continue
  run mv "$from" "$to"
  replace cwd "$old" "$new" "$to"
  # forks and branches point at their parent session file by absolute path
  replace parentSession "$from" "$to" "$pi_root"
done <<<"$pi_moves"

[[ -z $old_mem ]] || run mv "$old_mem" "$new_mem"

# tmux turns . and : into _ in session names
tmux_name() {
  local b
  b=$(basename "$1")
  printf '%s' "${b//[.:]/_}"
}
if tmux list-sessions >/dev/null 2>&1; then
  while IFS=$'\t' read -r name path; do
    if [[ $path == "$old" && $name == "$(tmux_name "$old")" ]]; then
      run tmux rename-session -t "=$name" "$(tmux_name "$new")"
    fi
  done < <(tmux list-sessions -F $'#{session_name}\t#{session_path}')
fi

[[ -n $dry ]] || echo "mvproj: moved to ${new/#"$HOME"/\~}"

#!/usr/bin/env bash
# make a fresh ~/dev/scratch git repo and print its path, or trash one.
# not mktemp: agents key sessions by folder, and macOS cleans /var/folders, which would break resuming them

set -euo pipefail

usage="Usage: scratch
       scratch rm [DIR]

  Make ~/dev/scratch/<date-time> as a git repo, print its path, and in zsh cd into it.
  From its top folder, mvproj NAME keeps it as ~/dev/NAME.

  rm moves DIR, a folder directly in ~/dev/scratch, to the trash and kills tmux sessions in it,
  and rex sessions whose panes are all in it.
  DIR defaults to the current folder.
  Refuses while any process other than the calling shell or those sessions' shells runs inside DIR."

die() {
  echo "scratch: $*" >&2
  exit 1
}

case ${1-} in
'')
  dir=$HOME/dev/scratch/$(date +%Y-%m-%d-%H%M%S)
  mkdir -p "$dir"
  git -C "$dir" init -q
  # trust it for claude, which keys trust on the repo root (docs: permissions, workspace trust)
  # rewritten in place, since claude owns the file and its mode
  if [[ -f $HOME/.claude.json ]]; then
    json=$(jq --arg p "$dir" '.projects[$p].hasTrustDialogAccepted = true' "$HOME/.claude.json")
    printf '%s\n' "$json" >"$HOME/.claude.json"
  fi
  echo "$dir"
  exit
  ;;
-h | --help)
  echo "$usage"
  exit
  ;;
rm) [[ $# -le 2 ]] || die "too many arguments" ;;
*)
  echo "$usage" >&2
  exit 1
  ;;
esac

[[ -d ${2:-.} ]] || die "not a folder: ${2:-.}"
dir=$(cd "${2:-.}" && pwd -P)
[[ -d $HOME/dev/scratch && $(dirname "$dir") == "$(cd "$HOME/dev/scratch" && pwd -P)" ]] ||
  die "not a folder directly in ~/dev/scratch: $dir"

# lsof below must not count this script as a process inside DIR
cd /

skip=" $$ "
skip_shell() {
  local comm
  comm=$(ps -o comm= -p "$1") || return 0
  case ${comm##*/} in
  sh | -sh | bash | -bash | zsh | -zsh | fish | -fish) skip+="$1 " ;;
  esac
}

# tmux sessions started in DIR, and their panes' shells, which the kill ends
sessions=$(tmux list-sessions -F $'#{session_path}\t#{session_name}' 2>/dev/null |
  awk -F '\t' -v d="$dir" '$1 == d || index($1, d "/") == 1 { print $2 }') || true
while IFS= read -r name; do
  [[ -n $name ]] || continue
  for pid in $(tmux list-panes -s -t "=$name" -F '#{pane_pid}'); do
    skip_shell "$pid"
  done
done <<<"$sessions"

# rex sessions whose every pane's processes sit in DIR, and those panes' shells, which the kill ends.
# a session with a pane elsewhere stays, so its shells in DIR count as busy below.
# rex keeps no session folder, so each session is asked for its panes' processes
panes_lua=$(
  cat <<'EOF'
local terminal = "com.superlogical.terminal"
local pids, cwds = {}, {}
for _, b in ipairs(rex.session.list_blocks({}).blocks) do
    local p = b.creator_name == terminal and rex.block.call(terminal, "process", { block_id = b.block_id })
    for _, proc in pairs(p and { p.child, p.foreground, unpack(p.ancestors or {}) } or {}) do
        pids[#pids + 1] = proc.pid
        cwds[#cwds + 1] = proc.cwd
    end
end
return { pids = pids, cwds = cwds }
EOF
)
rex_sessions=
for id in $(rex --autostart=false ls --json 2>/dev/null | jq -r '.sessions[].session_id'); do
  panes=$(rex --autostart=false 'do' -s "$id" --json -e "$panes_lua") || continue
  jq -e --arg d "$dir" '[.cwds[]] | length > 0 and all(. == $d or startswith($d + "/"))' <<<"$panes" >/dev/null || continue
  rex_sessions+="$id"$'\n'
  for pid in $(jq -r '.pids[]' <<<"$panes"); do
    skip_shell "$pid"
  done
done

# shells this command runs under may sit in DIR, as in mvproj.sh
pid=$PPID
while [[ $pid -gt 1 ]]; do
  skip_shell "$pid"
  pid=$(ps -o ppid= -p "$pid" | tr -d ' ') || break
done

busy=$(lsof -w -d cwd -Fpcn | awk -v old="$dir" -v skip="$skip" '
  /^p/ { pid = substr($0, 2) }
  /^c/ { comm = substr($0, 2) }
  /^n/ {
    path = substr($0, 2)
    if ((path == old || index(path, old "/") == 1) && index(skip, " " pid " ") == 0)
      print "  " pid " " comm " in " path
  }')
[[ -z $busy ]] || die "processes are running inside $dir:
$busy"

trash "$dir"
echo "scratch: trashed ${dir/#"$HOME"/\~}"
# last, since the calling shell may be in one of these sessions
while IFS= read -r name; do
  [[ -z $name ]] || tmux kill-session -t "=$name"
done <<<"$sessions"
while IFS= read -r id; do
  [[ -z $id ]] || rex --autostart=false kill "$id" >/dev/null
done <<<"$rex_sessions"

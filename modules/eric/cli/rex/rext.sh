#!/usr/bin/env bash
# sesh-pick for rex: pick a rex session, a sesh config entry, or a zoxide dir in fzf, then show it in the rex app.
# a config entry or dir opens the session named after it, and creates one there when none has that name.
# rex acts on the calling terminal's server, so a pick from a narwhal session opens on narwhal

# nerd font prompts: bolt for all, then the glyphs sesh puts on session, config, and zoxide rows
all=$'' config=$''
session=$'' dir=$''

# "<id>\t<label>" for each running session
sessions() {
  rex ls --json | jq -r '(.sessions // [])[] | "\(.session_id)\t\(.label)"'
}

# the id of the one session labeled $1, or nothing. rex allows duplicate labels, which fail here
session_id() {
  local ids
  ids=$(sessions | awk -F '\t' -v n="$1" '$2 == n { print $1 }')
  if [[ $ids == *$'\n'* ]]; then
    echo "rext: several sessions are labeled $1, pick one in the picker" >&2
    return 1
  fi
  printf '%s' "$ids"
}

# switches the app that shows this terminal, since rex refuses to guess when another app such as a phone is connected.
# the cmd-p popup sets REX_CLIENT itself (see rex/init.lua)
select_session() {
  local owner=''
  if [[ -z ${REX_CLIENT:-} && -n ${REX_BLOCK:-} ]]; then
    owner=$(rex block inspect "$REX_BLOCK" --json | jq -r '.block.owner // empty')
  fi
  rex ${owner:+-C "$owner"} 'do' session.select session_id="$1" >/dev/null
}

# the session named $1, created in $2 when none has that name
open_session() {
  local id
  id=$(session_id "$1") || exit 1
  [[ -n $id ]] || id=$(rex new "$1" --cwd "$2" --json | jq -r .session_id)
  select_session "$id"
}

open_dir() {
  local path
  path=$(realpath -m -- "${1/#\~/$HOME}")
  [[ -d $path ]] || {
    echo "rext: no such folder: $path" >&2
    exit 1
  }
  open_session "$(project-name "$path")" "$path"
}

open_config() {
  open_session "$1" "$(sesh list -c -j | jq -r --arg n "$1" 'first(.[] | select(.Name == $n) | .Path) // empty')"
}

# rows for a view, d all, t sessions, c config entries, z zoxide dirs, as "<session id or nothing><tab><icon> <name>".
# the all view lists a config entry's dir once (sesh's -d) and leaves out any whose session runs.
# only a dir whose folder name ends some label is looked up there, since project-name runs git
list() {
  local -A running=() ends=()
  local -a ids=() labels=()
  local id label row path base i
  while IFS=$'\t' read -r id label; do
    ids+=("$id") labels+=("$label")
    running[$label]=1 ends[${label##*/}]=1
  done < <(sessions)
  if [[ $1 == [dt] ]]; then
    for i in "${!ids[@]}"; do
      printf '%s\t\e[38;2;125;182;255m%s\e[39m %s\n' "${ids[i]}" "$session" "${labels[i]}"
    done
  fi
  local -A flags=([d]=-czd [c]=-c [z]=-z)
  [[ -n ${flags[$1]:-} ]] || return 0
  sesh list -i "${flags[$1]}" | while IFS= read -r row; do
    if [[ $1 == d ]]; then
      path=${row#* } base=${row##*/}
      # a label's last part has project-name's _ for . and :
      base=${base//[.:]/_}
      # sesh colors each row's icon
      [[ ${row%% *} == *"$config"* && -n ${running[$path]:-} ]] && continue
      # / has no folder name, and an empty key is an error in bash
      if [[ ${row%% *} == *"$dir"* && -n $base && -n ${ends[$base]:-} && -n ${running[$(project-name "$path")]:-} ]]; then
        continue
      fi
    fi
    printf '\t%s\n' "$row"
  done
}

sessions_only=0
while (($# > 0)); do
  case $1 in
  -h | --help)
    cat <<EOF
Usage: rext [--sessions] [TARGET]

  (none)       pick in fzf: ^a all ^t sessions ^g configs ^x zoxide ^d kill.
               ^n, or enter on text that matches nothing, creates ~/dev/<text> and opens it.
               ^n on an empty query opens a new ~/dev/scratch/<date-time> folder
  --sessions   start on running rex sessions only, as ^t does
  --list F     print the rows of view F (d all, t sessions, c configs, z zoxide), each with its session id or
               nothing, a tab, then the row the picker shows
  --kill ID    kill the session with id ID, as ^d does
  TARGET       show the session labeled TARGET, else open a sesh config entry or a dir by that name.
               a label that several sessions share fails, since only the picker tells them apart
EOF
    exit
    ;;
  --list)
    list "$2"
    exit
    ;;
  --kill)
    [[ -n $2 ]] && rex kill "$2" >/dev/null
    exit
    ;;
  --sessions) sessions_only=1 ;;
  *)
    id=$(session_id "$1") || exit 1
    if [[ -n $id ]]; then
      select_session "$id"
    elif sesh list -c -j | jq -e --arg n "$1" 'any(.[]; .Name == $n)' >/dev/null; then
      open_config "$1"
    else
      open_dir "$1"
    fi
    exit
    ;;
  esac
  shift
done

# the key help sits in a preview pane at the top, since an fzf header stays next to the prompt.
# it shows only in the full view, and the sessions view hides it
help=$'^a all ^t sessions ^g configs ^x zoxide ^d kill\n^n, or enter on no match: create ~/dev/<name>. empty ^n: a scratch folder'
shown='up,2,border-bottom,noinfo'
start_prompt=$all start_flags=d start_window=$shown
if ((sessions_only)); then
  start_prompt=$session start_flags=t start_window=hidden
fi

# the actions that switch to a view: its prompt icon, the help pane's window, and its list
show() {
  printf -v REPLY 'change-prompt(%s  )+change-preview-window(%s)+reload(%q --list %s)' "$1" "$2" "$0" "$3"
}

# ^n names a new project from the query, or on an empty one prints scratch/, which makes a folder with the scratch script
# shellcheck disable=SC2016
new_bind='ctrl-n:transform:[[ -n $FZF_QUERY ]] && echo print-query || echo "change-query(scratch/)+print-query"'

# enter on a match prints that row, with its session id and tab, though fzf shows and searches only the part after the tab.
# enter with no match, or ^n always, prints the typed text instead, which names a new project.
# ^n is needed since most short names fuzzy-match some zoxide dir
# the projects popup sets REXT_POPUP, so fzf fills it
height=60%
[[ -n ${REXT_POPUP:-} ]] && height=100%
# fzf exits 1 with no match and 130 on esc, which are no pick. any other failure, such as a rejected flag, is an error
printf -v preview 'printf %%s %q' "$help"
printf -v kill 'execute-silent(%q --kill {1})' "$0"
show "$all" "$shown" d
show_all=$REPLY
show "$session" hidden t
show_sessions=$REPLY
show "$config" "$shown" c
show_configs=$REPLY
show "$dir" "$shown" z
show_dirs=$REPLY
rc=0
sel=$(list "$start_flags" | fzf --height "$height" --border --border-label ' rext ' \
  --no-sort --ansi --prompt "$start_prompt  " --delimiter '\t' --with-nth 2.. \
  --preview "$preview" --preview-window "$start_window" --color 'preview-fg:#f38ba8' \
  --bind "tab:down,btab:up,enter:accept-or-print-query" --bind "$new_bind" \
  --bind "ctrl-a:$show_all" \
  --bind "ctrl-t:$show_sessions" \
  --bind "ctrl-g:$show_configs" \
  --bind "ctrl-x:$show_dirs" \
  --bind "ctrl-d:$kill+$show_all") || rc=$?
((rc == 0)) || {
  ((rc == 1 || rc == 130)) && exit 0
  exit "$rc"
}

if [[ $sel == *$'\t'* ]]; then
  id=${sel%%$'\t'*} row=${sel#*$'\t'}
  if [[ -n $id ]]; then
    select_session "$id"
    exit
  fi
  case ${row%% *} in
  "$config") open_config "${row#* }" ;;
  "$dir") open_dir "${row#* }" ;;
  esac
  exit
fi

name=$(printf '%s' "$sel" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
[[ -n $name ]] || exit 0
if [[ $name == scratch/ ]]; then
  open_dir "$(scratch)"
  exit
fi
mkdir -p "$HOME/dev/$name"
open_dir "$HOME/dev/$name"

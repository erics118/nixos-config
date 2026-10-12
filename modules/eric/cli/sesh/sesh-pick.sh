#!/usr/bin/env bash
# connect to a sesh session, config entry, dir, or zoxide match.
# with no arg, pick one in fzf: a popup inside tmux, inline outside it

# with no tmux server yet, connect from a clean zsh login env, since every future
# pane inherits the server's env. $SHELL is skipped as dev shells set it to bash
connect() {
  if tmux list-sessions >/dev/null 2>&1; then
    exec sesh connect "$1"
  fi
  local zsh
  zsh=$(command -v zsh)
  local vars=(HOME="$HOME" USER="$USER" SHELL="$zsh" TERM="${TERM:-}" LANG="${LANG:-}")
  # tmux's update-environment copies TERM_PROGRAM from the client, and yazi needs it to send images
  [[ -n ${TERM_PROGRAM:-} ]] && vars+=(TERM_PROGRAM="$TERM_PROGRAM")
  # a login zsh fills an unset LOGNAME from getlogin(), which can be root
  [[ -n ${LOGNAME:-} ]] && vars+=(LOGNAME="$LOGNAME")
  # launchd sets these per user session, and no shell startup file restores them
  [[ -n ${SSH_AUTH_SOCK:-} ]] && vars+=(SSH_AUTH_SOCK="$SSH_AUTH_SOCK")
  [[ -n ${TMPDIR:-} ]] && vars+=(TMPDIR="$TMPDIR")
  [[ -n ${SSH_CONNECTION:-} ]] && vars+=(SSH_CONNECTION="$SSH_CONNECTION")
  [[ -n ${XDG_RUNTIME_DIR:-} ]] && vars+=(XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR")
  # starting the server first lets continuum restore the saved sessions,
  # since sesh creating one under a restored name fails and exits without attaching
  # shellcheck disable=SC2016
  exec env -i "${vars[@]}" "$zsh" -lc 'tmux start-server; exec sesh connect "$1"' _ "$1"
}

# the running session started in a dir, found by path since sesh names a session in a repo after the repo and subpath
session_at() {
  local dir
  dir=$(realpath -m -- "${1/#\~/$HOME}")
  tmux list-sessions -F $'#{session_path}\t#{session_name}' 2>/dev/null | awk -F '\t' -v p="$dir" '$1 == p { print $2; exit }' || true
}

# the wezterm tab whose pane is on the tty, when wezterm runs on this machine
tab_on_tty() {
  command -v wezterm >/dev/null || return 1
  local tab
  tab=$(wezterm cli --no-auto-start list --format json 2>/dev/null | jq -r --arg t "$1" 'first(.[] | select(.tty_name == $t) | .tab_id) // empty')
  [[ -n $tab ]] && printf '%s\n' "$tab"
}

# hands a pick to wezterm's projects menu code, which focuses the tab and window that show it or opens a new tab (see wezterm/bar.lua open_project).
# it goes as a user variable written to a wezterm pane's tty, and the nonce makes each pick a new value
hand_off() {
  [[ -w $1 ]] || return 0
  printf '\e]1337;SetUserVar=open_project=%s\a' "$(printf '%s\t%s\t%s' "$2" "$3" "$EPOCHREALTIME" | base64 | tr -d '\n')" >"$1"
  exit 0
}

# a picked session goes to the wezterm tab that shows it, or a new tab, so each tab keeps one session.
# outside tmux this tab becomes the session unless another tab shows it, and without wezterm, as on a remote host, it connects in place.
# a tab that open_project spawned sets SESH_PICK_IN_PLACE, since handing its pick back would spawn another
go() {
  local name=$1 target=$2 via=${client_tty:-} tty
  [[ -n ${SESH_PICK_IN_PLACE:-} ]] && connect "$target"
  [[ -z $via && -n ${TMUX:-} ]] && via=$(tmux display -p '#{client_tty}')
  if [[ -n $via ]] && tab_on_tty "$via" >/dev/null; then
    hand_off "$via" "$name" "$target"
  fi
  # /dev/tty is only a wezterm pane when wezterm started this shell
  if [[ -z ${TMUX:-} && -n ${WEZTERM_PANE:-} ]]; then
    tty=$(tmux list-clients -F $'#{client_tty}\t#{session_name}' 2>/dev/null | awk -F '\t' -v s="$name" '$2 == s { print $1; exit }') || true
    if [[ -n $tty ]] && tab_on_tty "$tty" >/dev/null; then
      hand_off /dev/tty "$name" "$target"
    fi
  fi
  connect "$target"
}

# sesh's rows for the given list flags, with each running session's name in its alert colour,
# from @session-alert in tmux/tabline.conf
list() {
  local -A color=([fail]=$'\e[1;38;2;243;139;168m' [bell]=$'\e[1;38;2;250;179;135m' [ok]=$'\e[1;38;2;166;227;161m' [activity]=$'\e[1;38;2;137;180;250m')
  local -A alert=()
  local name a row
  while IFS=$'\t' read -r name a; do
    alert[$name]=$a
  done < <(tmux list-sessions -F $'#{session_name}\t#{E:@session-alert}' 2>/dev/null)
  sesh list -i"$1" | while IFS= read -r row; do
    name=${row#* }
    a=${alert[$name]:-}
    if [[ $row == *"$tmux"* && -n $a ]]; then
      printf '%s %s%s\e[0m\n' "${row%% *}" "${color[$a]}" "$name"
    else
      printf '%s\n' "$row"
    fi
  done
}

sessions_only=0 popup=0 list_flags=''
while (($# > 0)); do
  case $1 in
  -h | --help)
    cat <<EOF
Usage: sesh-pick [--sessions] [--popup] [TARGET]

  (none)      pick in fzf: ^a all ^t tmux ^g configs ^x zoxide ^d kill.
              ^n, or enter on text that matches nothing, creates ~/dev/<text> and opens it.
              ^n on an empty query opens a new ~/dev/scratch/<date-time> folder
  --sessions  start on running tmux sessions only, as ^t does
  --popup     run fzf in the current terminal, as tmux-popup does inside its popup
  --list F    print sesh list -iF with session names in their alert colours, as the picker shows them
  TARGET      connect to a sesh session, config entry, dir, or zoxide match.
              a running session's exact name goes to the wezterm tab that shows it
EOF
    exit
    ;;
  --list)
    # set popup too, so a reload inside tmux prints rows here instead of opening a popup
    list_flags=$2 popup=1
    shift
    ;;
  --sessions) sessions_only=1 ;;
  --popup) popup=1 ;;
  # a running session's exact name follows the tab rule, and anything else sesh resolves in place
  *)
    if tmux has-session -t "=$1" 2>/dev/null; then
      go "$1" "$1"
    fi
    connect "$1"
    ;;
  esac
  shift
done

# inside tmux the picker is a popup, which tmux-popup opens, styles, and switches to or from
if [[ -n ${TMUX:-} ]] && ((! popup)); then
  if ((sessions_only)); then exec tmux-popup sessions; else exec tmux-popup projects; fi
fi

# nerd font prompts: bolt for all, then the same glyphs sesh puts on tmux, config, and zoxide rows
all=$'' tmux=$'' config=$'' dir=$''

if [[ -n $list_flags ]]; then
  list "$list_flags"
  exit
fi

# the popup draws the border, so fzf fills it. outside tmux fzf draws its own, below the prompt line
look=(--height 60% --border --border-label ' sesh ')
((popup)) && look=()

# closing the popup shows the cursor where it was for a moment, so every close first gives the cursor the background
# colour (OSC 12) through the tmux client's terminal (from tmux-popup), and it is reset (OSC 112) once the popup is gone.
# outside the popup hide stays a no-op
client_tty=''
((popup)) && client_tty=${TMUX_POPUP_CLIENT:-}
# the sequences end in BEL, since a transform output loses the backslash of ESC \
hide=''
if [[ -w $client_tty ]]; then
  hide="execute-silent(printf %s $(printf %q $'\e]12;#1e1e2e\a') > $(printf %q "$client_tty"))+"
fi
# the tmux server runs the reset, since this script's own children die with the popup
unhide() {
  [[ -w $client_tty ]] || return 0
  tmux run-shell -b "sleep 0.15; printf '\\033]112\\007' > $(printf %q "$client_tty")"
}

# the key help sits in a preview pane at the top, since an fzf header stays next to the prompt.
# it shows only in the full view, and the sessions view hides it
help=$'^a all ^t tmux ^g configs ^x zoxide ^d kill\n^n, or enter on no match: create ~/dev/<name>. empty ^n: a scratch folder'
shown='up,2,border-bottom,noinfo'
start_prompt=$all start_flags=d start_window=$shown
if ((sessions_only)); then
  start_prompt=$tmux start_flags=t start_window=hidden
fi

# the actions that switch to a view: its prompt icon, the help pane's window, and its list
show() {
  printf 'change-prompt(%s  )+change-preview-window(%s)+reload(%q --list %s)' "$1" "$2" "$0" "$3"
}

# cmd-p reaches an open picker as ctrl-alt-p (see scripts/tmux-popup.sh).
# it switches an open picker to the projects view, or closes it when that view is already shown
toggle() {
  # shellcheck disable=SC2016
  printf '%s:transform:[[ $FZF_PROMPT == %q* ]] && echo %q || echo %q' "$1" "$2" "${hide}abort" "$(show "$2" "$3" "$4")"
}
toggles=(--bind "$(toggle ctrl-alt-p "$all" "$shown" d)")
# a remote tmux sends cmd-j and cmd-e into the popup as ctrl-alt-j and ctrl-alt-y, and tmux-popup swaps the picker for that popup
if [[ -n $client_tty ]]; then
  toggles+=(--bind "ctrl-alt-j:execute-silent(tmux-popup scratch $(printf %q "$client_tty"))"
  --bind "ctrl-alt-y:execute-silent(tmux-popup files $(printf %q "$client_tty"))")
fi

# ^n names a new project from the query, or on an empty one a dated scratch folder, as the scratch shell function makes (see zsh/init.zsh)
# shellcheck disable=SC2016
new_bind=$(printf 'ctrl-n:transform:[[ -n $FZF_QUERY ]] && echo %q || echo "change-query(scratch/$(date +%%Y-%%m-%%d-%%H%%M%%S))+"%q' "${hide}print-query" "${hide}print-query")

# enter on a match prints that row, which starts with a sesh icon.
# enter with no match, or ^n always, prints the typed text instead, which names a new project.
# ^n is needed since most short names fuzzy-match some zoxide dir
sel=$(list "$start_flags" | fzf "${look[@]}" \
  --no-sort --ansi --prompt "$start_prompt  " \
  --preview "printf %s $(printf %q "$help")" --preview-window "$start_window" --color 'preview-fg:#f38ba8,bg:-1' \
  --bind "tab:down,btab:up,enter:${hide}accept-or-print-query" --bind "$new_bind" \
  --bind "esc:${hide}abort,ctrl-c:${hide}abort" "${toggles[@]}" \
  --bind "ctrl-a:$(show "$all" "$shown" d)" \
  --bind "ctrl-t:$(show "$tmux" hidden t)" \
  --bind "ctrl-g:$(show "$config" "$shown" c)" \
  --bind "ctrl-x:$(show "$dir" "$shown" z)" \
  --bind "ctrl-d:execute-silent(tmux kill-session -t ={2..})+$(show "$all" "$shown" d)") &&
  status=0 || status=$?
unhide
((status == 0)) || exit 0

case ${sel%% *} in
"$tmux" | "$config") go "${sel#* }" "$sel" ;;
"$dir") go "$(session_at "${sel#* }")" "$sel" ;;
esac

name=$(printf '%s' "$sel" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
[[ -n $name ]] || exit 0
mkdir -p "$HOME/dev/$name"
go "$(session_at "$HOME/dev/$name")" "$HOME/dev/$name"

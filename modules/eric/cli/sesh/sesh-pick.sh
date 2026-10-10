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
  # shellcheck disable=SC2016
  exec env -i "${vars[@]}" "$zsh" -lc 'exec sesh connect "$1"' _ "$1"
}

sessions_only=0 popup=0
while (($# > 0)); do
  case $1 in
  -h | --help)
    cat <<EOF
Usage: sesh-pick [--sessions] [--popup] [TARGET]

  (none)      pick in fzf: ^a all ^t tmux ^g configs ^x zoxide ^d kill.
              ^n, or enter on text that matches nothing, creates ~/dev/<text> and opens it
  --sessions  start on running tmux sessions only, as ^t does
  --popup     run fzf in the current terminal, as tmux-popup does inside its popup
  TARGET      connect to a sesh session, config entry, dir, or zoxide match
EOF
    exit
    ;;
  --sessions) sessions_only=1 ;;
  --popup) popup=1 ;;
  *) connect "$1" ;;
  esac
  shift
done

# inside tmux the picker is a popup, which tmux-popup opens, styles, and switches to or from
if [[ -n ${TMUX:-} ]] && ((! popup)); then
  if ((sessions_only)); then exec tmux-popup sessions; else exec tmux-popup projects; fi
fi

# nerd font prompts: bolt for all, then the same glyphs sesh puts on tmux, config, and zoxide rows
all=$'' tmux=$'' config=$'' dir=$''

# the popup draws the border, so fzf fills it. outside tmux fzf draws its own, below the prompt line
look=(--height 60% --border --border-label ' sesh ')
((popup)) && look=()

# closing the popup shows the cursor where it was for a moment, so every close first gives the cursor the background
# colour (OSC 12) through the tmux client's terminal (from tmux-popup), and it is reset (OSC 112) once the popup is gone.
# outside the popup hide stays a no-op
client_tty=''
((popup)) && client_tty=${SESH_CLIENT_TTY:-}
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
help=$'^a all ^t tmux ^g configs ^x zoxide ^d kill\n^n, or enter on no match: create ~/dev/<name>'
shown='up,2,border-bottom,noinfo'
start_prompt=$all start_list='sesh list -id' start_window=$shown
if ((sessions_only)); then
  start_prompt=$tmux start_list='sesh list -it' start_window=hidden
fi

# the actions that switch to a view: its prompt icon, the help pane's window, and its list
show() {
  printf 'change-prompt(%s  )+change-preview-window(%s)+reload(sesh list -i%s)' "$1" "$2" "$3"
}

# cmd-k and cmd-p reach an open picker as ctrl-alt-k and ctrl-alt-p (see scripts/tmux-popup.sh).
# each switches an open picker to its own view, or closes it when that view is already shown
toggle() {
  # shellcheck disable=SC2016
  printf '%s:transform:[[ $FZF_PROMPT == %q* ]] && echo %q || echo %q' "$1" "$2" "${hide}abort" "$(show "$2" "$3" "$4")"
}
# each needs its own --bind, since a key:action:arg bind runs to the end of its string
toggles=(--bind "$(toggle ctrl-alt-k "$tmux" hidden t)" --bind "$(toggle ctrl-alt-p "$all" "$shown" d)")

# enter on a match prints that row, which starts with a sesh icon.
# enter with no match, or ^n always, prints the typed text instead, which names a new project.
# ^n is needed since most short names fuzzy-match some zoxide dir
sel=$($start_list | fzf "${look[@]}" \
  --no-sort --ansi --prompt "$start_prompt  " \
  --preview "printf %s $(printf %q "$help")" --preview-window "$start_window" --color 'preview-fg:#f38ba8' \
  --bind "tab:down,btab:up,enter:${hide}accept-or-print-query,ctrl-n:${hide}print-query" \
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
"$tmux" | "$config" | "$dir") connect "$sel" ;;
esac

name=$(printf '%s' "$sel" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
[[ -n $name ]] || exit 0
mkdir -p "$HOME/dev/$name"
connect "$HOME/dev/$name"

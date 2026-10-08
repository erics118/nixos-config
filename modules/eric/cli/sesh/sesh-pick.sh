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

case ${1-} in
-h | --help)
  cat <<EOF
Usage: sesh-pick [TARGET]

  (none)    pick in fzf: ^a all ^t tmux ^g configs ^x zoxide ^d kill
  TARGET    connect to a sesh session, config entry, dir, or zoxide match
EOF
  exit
  ;;
esac

if (($# > 0)); then
  connect "$1"
fi

# nerd font prompts: bolt for all, then the same glyphs sesh puts on tmux, config, and zoxide rows
all=$'' tmux=$'' config=$'' dir=$''

# fzf honors only the last of --tmux and --height, so pass just the one that fits.
# inside tmux (and run-shell, which has no terminal) it must be the popup
if [[ -n ${TMUX:-} ]]; then
  size=(--tmux '40%,60%')
else
  size=(--height 60%)
fi

sel=$(sesh list -id | fzf "${size[@]}" --border \
  --no-sort --ansi --no-preview --border-label ' sesh ' --prompt "$all  " \
  --header '^a all ^t tmux ^g configs ^x zoxide ^d kill' \
  --bind 'tab:down,btab:up' \
  --bind "ctrl-a:change-prompt($all  )+reload(sesh list -id)" \
  --bind "ctrl-t:change-prompt($tmux  )+reload(sesh list -it)" \
  --bind "ctrl-g:change-prompt($config  )+reload(sesh list -ic)" \
  --bind "ctrl-x:change-prompt($dir  )+reload(sesh list -iz)" \
  --bind "ctrl-d:execute-silent(tmux kill-session -t {2..})+change-prompt($all  )+reload(sesh list -id)") ||
  exit 0

connect "$sel"

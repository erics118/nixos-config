#!/usr/bin/env bash
# attach to a persistent tmux session on a remote host over mosh
# -a falls back to autossh

use_autossh=0
if [[ ${1:-} == -a || ${1:-} == --autossh ]]; then
  use_autossh=1
  shift
fi

host=${1:-}
session=${2:-main}

if [[ -z $host ]]; then
  printf >&2 'usage: rtmux [-a|--autossh] <host> [session]\n'
  printf >&2 '       rtmux <host> --ls\n'
  exit 1
fi

case $session in
--ls)
  ssh "$host" tmux ls
  ;;
*)
  if ((use_autossh)); then
    # properly quote session for the remote shell string
    printf -v session %q "$session"
    # opt out of multiplexing so autossh monitors a connection it owns
    AUTOSSH_GATETIME=0 autossh -M 0 \
      -o ControlMaster=no -o ControlPath=none \
      "$host" -t "tmux new -A -s $session"
  else
    mosh "$host" -- tmux new -A -s "$session"
  fi
  ;;
esac

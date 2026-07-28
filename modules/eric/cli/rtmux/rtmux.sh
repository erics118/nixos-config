#!/usr/bin/env bash
# attach to a persistent tmux session on a remote host, kept alive by autossh

host=${1:-}
arg=${2:-main}

if [[ -z $host ]]; then
  printf >&2 'usage: rtmux <host> [session]\n'
  printf >&2 '       rtmux <host> --ls\n'
  exit 1
fi

case $arg in
--ls)
  ssh "$host" tmux ls
  ;;
*)
  # quote for the remote shell, which evaluates the -t command string
  printf -v remote %q "$arg"
  # -D drops stale clients left attached by a dropped link, which would
  # otherwise clamp the window to their old size
  # opt out of multiplexing so autossh monitors a connection it owns
  AUTOSSH_GATETIME=0 autossh -M 0 \
    -o ControlMaster=no -o ControlPath=none \
    "$host" -t "tmux new -A -D -s $remote"
  ;;
esac

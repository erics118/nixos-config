#!/usr/bin/env bash
# attach to a persistent session on a remote host, picking the host in fzf if none given.
# runs sesh-pick, else tmux, else a plain shell, over mosh on the tailnet if the host has it, else autossh (-a forces it)

# nerd font icons: bolt for all (as in sesh-pick), gear for ssh config, tailscale for the tailnet
all=$'' config=$'' tailnet=$'\U000f15fc'

# color only the icon, as sesh does on its rows
colored() {
  printf '\e[%sm%s\e[39m' "$1" "$2"
}

# "<icon> <host>" rows: ssh config aliases, and online tailnet peers that run tailscale ssh.
# all lists both, keeping the config row when a host is in each
hosts() {
  case $1 in
  config)
    awk 'tolower($1) == "host" { for (i = 2; i <= NF; i++) if ($i !~ /[*?!]/ && $i !~ /github/) print $i }' \
      ~/.ssh/config ~/.ssh/config.local ~/.orbstack/ssh/config 2>/dev/null | sort -u | sed "s/^/$(colored 90 "$config") /"
    ;;
  tailnet)
    if command -v tailscale >/dev/null; then
      tailscale status --json 2>/dev/null |
        jq -r '.Peer[] | select(.Online and ((.sshHostKeys // []) | length > 0)) | .DNSName | split(".")[0]' |
        sort -u | sed "s/^/$(colored 32 "$tailnet") /"
    fi
    ;;
  *) {
    hosts config
    hosts tailnet
  } | awk '!seen[$2]++' ;;
  esac
}

use_autossh=0
if [[ ${1:-} == -a || ${1:-} == --autossh ]]; then
  use_autossh=1
  shift
fi

# --hosts prints bare names for completion. --rows keeps the icons for the picker's reloads
case ${1:-} in
--hosts)
  hosts all | cut -d' ' -f2
  exit
  ;;
--rows)
  hosts "${2:-all}"
  exit
  ;;
esac

host=${1:-}
target=${2:-}

# both layers use the C-b prefix, so the local tmux would swallow it
if [[ -n ${TMUX:-} && $target != --ls ]]; then
  printf >&2 'rtmux: inside tmux, run it from a plain wezterm tab\n'
  exit 1
fi

if [[ -z $host ]]; then
  host=$(hosts all | fzf --height 40% --border --ansi --no-preview --border-label ' hosts ' --prompt "$all  " \
    --header '^a all ^g config ^t tailnet' \
    --bind "ctrl-a:change-prompt($all  )+reload($0 --rows all)" \
    --bind "ctrl-g:change-prompt($config  )+reload($0 --rows config)" \
    --bind "ctrl-t:change-prompt($tailnet  )+reload($0 --rows tailnet)") || exit 0
  host=${host#* }
fi

if [[ $target == --ls ]]; then
  exec ssh "$host" tmux ls
fi

# one round trip, reusing the shared control connection.
# the trailing true keeps a missing last tool from reading as a failed connection
if ! probe=$(ssh "$host" 'for c in sesh-pick tmux mosh-server; do command -v "$c" >/dev/null && echo "$c"; done; true'); then
  printf >&2 'rtmux: cannot reach %s\n' "$host"
  exit 1
fi
mapfile -t caps <<<"$probe"
has() {
  local c
  for c in "${caps[@]}"; do
    [[ $c == "$1" ]] && return 0
  done
  return 1
}

if has sesh-pick; then
  remote=(sesh-pick ${target:+"$target"})
elif has tmux; then
  # prefixed with the local user, since a shared remote account may have other people's sessions.
  # a name completed from the remote list already has the prefix
  name=${target:-main}
  [[ $name == "$USER"-* ]] || name=$USER-$name
  remote=(tmux new -A -s "$name")
else
  printf >&2 'rtmux: no tmux on %s, opening a plain ssh shell that will not persist\n' "$host"
  exec ssh "$host"
fi

# mosh only over the tailnet: public and lan addresses may block its udp ports
hostname=$(ssh -G "$host" | awk '$1 == "hostname" { print $2 }')

if ((use_autossh)) || ! has mosh-server || [[ $hostname != *.ts.net ]]; then
  # properly quote the command for the remote shell string
  printf -v cmd '%q ' "${remote[@]}"
  # opt out of multiplexing so autossh monitors a connection it owns
  AUTOSSH_GATETIME=0 exec autossh -M 0 \
    -o ControlMaster=no -o ControlPath=none \
    "$host" -t "${cmd% }"
else
  exec mosh --predict-overwrite "$host" -- "${remote[@]}"
fi

#!/usr/bin/env bash
# attach to a persistent session on a remote host, picking the host in fzf if none given.
# a host of this config runs sesh-pick, any other a private tmux server, else a plain shell, over mosh on the tailnet if it has it, else autossh (-a forces it).
# own_hosts and remote_dir come from rtmux.nix

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
    # a missing file is skipped, since gawk stops at the first file it cannot open
    awk 'BEGINFILE { if (ERRNO != "") nextfile } tolower($1) == "host" { for (i = 2; i <= NF; i++) if ($i !~ /[*?!]/ && $i !~ /github/) print $i }' \
      ~/.ssh/config ~/.ssh/config.local ~/.orbstack/ssh/config 2>/dev/null | sort -u | sed "s/^/$(colored 90 "$config") /"
    ;;
  tailnet)
    # a stopped tailscaled or a logged-out one, with no peers, lists nothing instead of failing the picker
    if command -v tailscale >/dev/null; then
      tailscale status --json 2>/dev/null |
        jq -r '(.Peer // {})[] | select(.Online and ((.sshHostKeys // []) | length > 0)) | .DNSName | split(".")[0]' |
        sort -u | sed "s/^/$(colored 32 "$tailnet") /" || true
    fi
    ;;
  *) {
    hosts config
    hosts tailnet
  } | awk '!seen[$2]++' ;;
  esac
}

# ssh options for the listing modes, which must fail fast instead of asking for a password
quick=(-o BatchMode=yes -o ConnectTimeout=1)

# the tools the host has, one per line, then the version of rtmux's files there if any, in one round trip that takes ssh options.
# the trailing true keeps a missing last tool from reading as a failed connection
caps=()
probe() {
  local out
  out=$(ssh "$@" "$host" 'for c in sesh-pick tmux mosh-server tmux-sessions; do command -v "$c" >/dev/null && echo "$c"; done; cat ~/.local/erics118/.version 2>/dev/null; true') || return 1
  mapfile -t caps <<<"$out"
}
has() {
  local c
  for c in "${caps[@]}"; do
    [[ $c == "$1" ]] && return 0
  done
  return 1
}

# a host this flake configures, by name, or by the tmux-sessions on its PATH when an alias such as narwhal-ip reaches it
own() {
  has tmux-sessions && return 0
  local h
  for h in "${own_hosts[@]}"; do
    [[ $h == "$host" ]] && return 0
  done
  return 1
}

# a host outside this config gets tmux-sessions and a tmux config only in ~/.local/erics118, off its PATH, for a private tmux server.
# each file is written beside its target and moved over it, so a half-copied file never runs.
# takes ssh options
version=${remote_dir##*/}
install_private() {
  has "$version" && return 0
  {
    echo 'set -e'
    echo 'mkdir -p ~/.local/erics118'
    echo "cat > ~/.local/erics118/tmux-sessions.new <<'RTMUX_EOF'"
    cat "$remote_dir/tmux-sessions"
    echo 'RTMUX_EOF'
    echo 'chmod 755 ~/.local/erics118/tmux-sessions.new'
    echo 'mv ~/.local/erics118/tmux-sessions.new ~/.local/erics118/tmux-sessions'
    echo "cat > ~/.local/erics118/tmux.conf.new <<'RTMUX_EOF'"
    cat "$remote_dir/tmux.conf"
    echo 'RTMUX_EOF'
    echo 'mv ~/.local/erics118/tmux.conf.new ~/.local/erics118/tmux.conf'
    echo "echo $version > ~/.local/erics118/.version"
  } | ssh "$@" "$host" sh
}

# the host's sessions as name, tab, alert (see tmux-sessions/tmux-sessions.sh). takes ssh options
sessions_on() {
  if own; then
    if has tmux-sessions; then
      ssh "$@" "$host" tmux-sessions
    fi
  elif has tmux; then
    # shellcheck disable=SC2016
    install_private "$@" && ssh "$@" "$host" '"$HOME/.local/erics118/tmux-sessions" -L erics118'
  fi
}

case ${1:-} in
-h | --help)
  cat <<EOF
Usage: rtmux [-a] [HOST] [SESSION | --ls | --uninstall]
       rtmux [-a] -- HOST [SESSION]
       rtmux --sessions [HOST...]

  -a, --autossh   use autossh even when mosh is available
  --              take HOST and SESSION as names, so a session named --ls or --uninstall opens
  HOST            ssh config alias or tailnet host, picked in fzf if omitted
  SESSION         session to open on HOST (default: the remote sesh-pick, else main)
  --ls            list tmux sessions on HOST
  --uninstall     end the private tmux server on HOST and remove the files rtmux installed there
  --sessions      list sessions on every online host of this config and each HOST, as host, session, and alert
EOF
  exit
  ;;
esac

use_autossh=0
if [[ ${1:-} == -a || ${1:-} == --autossh ]]; then
  use_autossh=1
  shift
fi

# a host that starts with - would reach ssh as an option, and a pane title can name any host
check_host() {
  if [[ $host == -* ]]; then
    printf >&2 'rtmux: bad host %s\n' "$host"
    exit 1
  fi
}

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
--sessions-of)
  # one host's sessions, each line led by the host
  host=$2
  check_host
  if probe "${quick[@]}"; then
    sessions_on "${quick[@]}" | awk -v h="$host" '{ print h "\t" $0 }'
  fi
  exit 0
  ;;
--sessions)
  shift
  # the gui runs this, and its PATH lacks /usr/local/bin, where the macos tailscale cli lives
  PATH=$PATH:/usr/local/bin
  # own hosts online on the tailnet, which leaves out this machine, then the named hosts
  online=$(tailscale status --json 2>/dev/null | jq -r '.Peer[] | select(.Online) | .DNSName | split(".")[0]' || true)
  for h in "${own_hosts[@]}"; do
    if grep -qxF "$h" <<<"$online"; then
      set -- "$@" "$h"
    fi
  done
  # every host at once, each cut off after 3s so a hung one cannot hold up the projects menu
  while IFS= read -r h; do
    [[ -n $h ]] && timeout 3 "$0" --sessions-of "$h" &
  done < <(printf '%s\n' "$@" | sort -u)
  wait
  exit 0
  ;;
esac

# after --, HOST and SESSION are names, never modes
mode=''
if [[ ${1:-} == -- ]]; then
  shift
elif [[ ${2:-} == --ls || ${2:-} == --uninstall ]]; then
  mode=$2
  set -- "$1"
fi
host=${1:-}
target=${2:-}

# both layers use the C-b prefix, so the local tmux would swallow it
if [[ -n ${TMUX:-} && -z $mode ]]; then
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
check_host

if [[ $mode == --ls ]]; then
  if ! probe "${quick[@]}"; then
    printf >&2 'rtmux: cannot reach %s\n' "$host"
    exit 1
  fi
  sessions_on "${quick[@]}"
  exit 0
fi

# undoes install_private, ending the private server and its sessions first
if [[ $mode == --uninstall ]]; then
  # shellcheck disable=SC2016
  exec ssh "$host" 'tmux -L erics118 kill-server 2>/dev/null; rm -rf "$HOME/.local/erics118"'
fi

if ! probe; then
  printf >&2 'rtmux: cannot reach %s\n' "$host"
  exit 1
fi

if own && has sesh-pick; then
  remote=(sesh-pick ${target:+"$target"})
elif ! own && has tmux; then
  install_private
  # @host names the host as rtmux reaches it, for the window title remote.conf sets.
  # it is per session, so a second alias to the same host relabels only the session it opens
  # shellcheck disable=SC2016
  remote=(sh -c 'exec tmux -L erics118 -f "$HOME/.local/erics118/tmux.conf" new -A -s "$1" \; set @host "$2"' _ "${target:-main}" "$host")
elif has tmux; then
  remote=(tmux new -A -s "${target:-main}")
else
  printf >&2 'rtmux: no tmux on %s, opening a plain ssh shell that will not persist\n' "$host"
  exec ssh "$host"
fi

# a failed remote command holds its error on screen, since mosh only prints that it is exiting and autossh would rerun it.
# wezterm/keys.lua tells an rtmux pane by the wrapper's name
# shellcheck disable=SC2016
remote=(sh -c '"$@" || { echo "rtmux: $1 exited $?, press enter"; read -r _; }' rtmux-remote "${remote[@]}")

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

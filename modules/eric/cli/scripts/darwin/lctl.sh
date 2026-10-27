#!/usr/bin/env bash
# start/stop/restart/status launchd user agents by short name
# resolves, in order:
#   ~/Library/LaunchAgents/<name>
#   ~/Library/LaunchAgents/com.erics118.<name>
#   ~/Library/LaunchAgents/org.nixos.<name>
#   ~/Library/LaunchAgents/org.nix-community.home.<name>
#   ~/Library/LaunchAgents/*<name>*  (if unique)

set -euo pipefail

cmd=${1-}
name=${2-}
if [[ -z $cmd || -z $name ]]; then
  echo "usage: lctl <start|stop|restart|status> <name>" >&2
  exit 2
fi
domain="gui/$(id -u)"
dir="$HOME/Library/LaunchAgents"
if [[ -f $dir/$name.plist ]]; then
  plist=$dir/$name.plist
elif [[ -f $dir/com.erics118.$name.plist ]]; then
  plist=$dir/com.erics118.$name.plist
elif [[ -f $dir/org.nixos.$name.plist ]]; then
  plist=$dir/org.nixos.$name.plist
elif [[ -f $dir/org.nix-community.home.$name.plist ]]; then
  plist=$dir/org.nix-community.home.$name.plist
else
  shopt -s nullglob
  matches=("$dir"/*"$name"*.plist)
  if ((${#matches[@]} == 1)); then
    plist=${matches[0]}
  else
    echo "lctl: no unique agent matching '$name'" >&2
    exit 1
  fi
fi
label=${plist##*/}
label=${label%.plist}
# a job disabled by a tool's own --stop-service cannot be bootstrapped until enabled
case $cmd in
start)
  launchctl enable "$domain/$label"
  launchctl bootstrap "$domain" "$plist"
  ;;
stop) launchctl bootout "$domain" "$plist" ;;
restart)
  # bootout fails when the agent isn't loaded, which restart allows
  launchctl bootout "$domain" "$plist" 2>/dev/null || true
  launchctl enable "$domain/$label"
  launchctl bootstrap "$domain" "$plist"
  ;;
status) launchctl print "$domain/$label" ;;
*)
  echo "lctl: unknown command '$cmd'" >&2
  exit 2
  ;;
esac

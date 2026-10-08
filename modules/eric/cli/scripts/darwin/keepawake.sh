#!/usr/bin/env bash
# keeps the mac awake, lid closed included, until this process exits

set -euo pipefail

show_help() {
  cat <<EOF
keepawake - Keep the Mac awake, lid closed included, until this process exits

Usage: keepawake [OPTIONS]

Sets 'pmset -a disablesleep 1' and holds it while running. Ctrl-C, kill,
or closing the terminal sets it back to 0. After a kill -9, sketchybar's
sleep item resets it within about 60 seconds. Only one instance runs at a time.

Options:
  -h, --help  Show this help message

Examples:
  keepawake       Hold until Ctrl-C
  keepawake &     Hold in the background, stop with 'pkill -f /bin/keepawake'

EOF
  exit 0
}

case "${1:-}" in
-h | --help) show_help ;;
"") ;;
*)
  echo "Error: unknown argument '$1'. Use 'keepawake -h' for help." >&2
  exit 1
  ;;
esac

lock=/tmp/keepawake.lock
exec 9>"$lock"
if ! /usr/bin/lockf -s -t 0 9; then
  echo "keepawake: already running" >&2
  exit 1
fi

sleep_pid=
# sudo pmset needs no password through the NOPASSWD rules in modules/features/base/darwin.nix
cleanup() {
  trap - EXIT INT TERM HUP
  kill "$sleep_pid" 2>/dev/null || true
  /usr/bin/sudo /usr/bin/pmset -a disablesleep 0
}
trap cleanup EXIT
trap exit INT TERM HUP

/usr/bin/sudo /usr/bin/pmset -a disablesleep 1

# stops once something else turns the setting back off
while [[ $(/usr/bin/pmset -g) =~ SleepDisabled[[:space:]]+1 ]]; do
  # the sleep must not inherit the lock, or a kill -9 would leave it held
  sleep 60 9>&- &
  sleep_pid=$!
  # wait, unlike a foreground sleep, returns as soon as a trapped signal arrives
  wait "$sleep_pid" || true
done

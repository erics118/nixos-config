#!/usr/bin/env bash
# format the edited file with the project's own treefmt, reached through the
# direnv devShell (nix-direnv cached, no flake eval, no store copy).
# silently no-ops for non-direnv projects or shells without treefmt.
set -u
source "$(dirname "$0")/lib.sh"

# roots whose .envrc should not trigger formatting
ignored_roots=("$HOME" "$HOME/dev" "$HOME/dev/other")

hook_read_file_path

[ -f "$HOOK_FILE" ] || exit 0
command -v direnv >/dev/null 2>&1 || exit 0

# walk up to the project root (dir holding .envrc)
d=$(dirname "$HOOK_FILE")
while [ "$d" != "/" ] && [ ! -f "$d/.envrc" ]; do
  d=$(dirname "$d")
done

[ -f "$d/.envrc" ] || exit 0
# direnv tracks allowed .envrc files by resolved path, so a symlinked root reads as blocked
d=$(realpath "$d")

for r in "${ignored_roots[@]}"; do
  [ "$d" != "$r" ] || exit 0
done

cd "$d" || exit 0
direnv exec "$d" treefmt "$HOOK_FILE" >/dev/null 2>&1 || true
exit 0

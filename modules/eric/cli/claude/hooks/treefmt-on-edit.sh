#!/usr/bin/env bash
# format the edited file with the project's own treefmt, reached through the
# direnv devShell (nix-direnv cached, no flake eval, no store copy).
# silently no-ops for non-direnv projects or shells without treefmt.
set -u

f=$(jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
[ -n "$f" ] && [ -f "$f" ] || exit 0
command -v direnv >/dev/null 2>&1 || exit 0

# walk up to the project root (dir holding .envrc)
d=$(dirname "$f")
while [ "$d" != "/" ] && [ ! -f "$d/.envrc" ]; do
  d=$(dirname "$d")
done
[ -f "$d/.envrc" ] || exit 0
# roots whose .envrc should not trigger formatting
ignored_roots=("$HOME" "$HOME/dev" "$HOME/dev/other")
for r in "${ignored_roots[@]}"; do
  [ "$d" != "$r" ] || exit 0
done

cd "$d" || exit 0
direnv exec "$d" treefmt "$f" >/dev/null 2>&1 || true
exit 0

#!/usr/bin/env bash
# block sudo -n on macOS. it never prompts, so it reports sudo as unavailable even though
# Touch ID would approve a plain sudo. elsewhere sudo -n is the right non-hanging check
set -u
source "$(dirname "$0")/lib.sh"

[ "$(uname)" = Darwin ] || exit 0

hook_require rg jq awk
hook_read_command
hook_bare_command
reason='sudo -n never prompts, so it gives a false negative. Run plain sudo and let Touch ID prompt.'

# walk sudo's options up to the command it runs. these options take a value as the next word
while IFS= read -r args; do
  read -ra words <<<"$args"
  skip=
  for w in "${words[@]}"; do
    [ -n "$skip" ] && {
      skip=
      continue
    }
    case "$w" in
    --non-interactive) hook_deny "$reason" ;;
    --*) ;;
    -[ugpCDhRTU]) skip=1 ;;
    -*n*) hook_deny "$reason" ;;
    -*) ;;
    *) break ;;
    esac
  done
done < <(printf '%s' "$HOOK_BARE" | rg -o -r '$1' '(?:^|[;&|(]\s*)sudo\s+([^;&|)]*)')

exit 0

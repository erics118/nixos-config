#!/usr/bin/env bash
# block NEWLY introduced smart punctuation in written content; CLAUDE.md wants plain ASCII.
# only denies when an edit adds more smart chars than it removes, so edits that merely
# preserve existing ones are not blocked.
set -u
source "$HOME/.claude/hooks/lib.sh"

hook_require rg jq
HOOK_INPUT=$(cat)

pat='[\x{2013}\x{2014}\x{2018}\x{2019}\x{201C}\x{201D}\x{2026}]'
cnt() { printf '%s' "$1" | rg -oN "$pat" 2>/dev/null | wc -l | tr -d ' '; }

new=$(printf '%s' "$HOOK_INPUT" | jq -r '[ .tool_input.content, .tool_input.new_string, (.tool_input.edits[]?.new_string) ] | map(select(.!=null)) | join("\n")')
old=$(printf '%s' "$HOOK_INPUT" | jq -r '[ .tool_input.old_string, (.tool_input.edits[]?.old_string) ] | map(select(.!=null)) | join("\n")')
[ -n "$new" ] || exit 0

if [ "$(cnt "$new")" -gt "$(cnt "$old")" ]; then
  hook_deny 'this write introduces smart punctuation (em/en dash, curly quotes, ellipsis). use plain ASCII: -, straight quotes, ... instead. rewrite and retry.'
fi
exit 0

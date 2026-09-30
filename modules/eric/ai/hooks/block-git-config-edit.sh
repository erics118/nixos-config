#!/usr/bin/env bash
# block direct writes to a repo's git config files, so config changes go through `git config`,
# where block-agent-commit.sh keeps agents from setting the eric-agent keys
set -u
source "$(dirname "$0")/lib.sh"

hook_require jq rg awk
HOOK_INPUT=$(cat)
reason='is a git config file. Change git config with `git config`, and read it with Read or `git config --list --show-origin`.'

# .git/config, and config or config.worktree under .git/worktrees or .git/modules
is_git_config() {
  printf '%s' "$1" | rg -q '(?:^|[/=])\.git/(?:[^/\s]+/)*config(?:\.worktree)?$'
}

file=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
if [ -n "$file" ]; then
  is_git_config "$file" && hook_deny "$file $reason"
  exit 0
fi

HOOK_COMMAND=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$HOOK_COMMAND" ] || exit 0
hook_bare_command

# ... > file, ... >> file, or tee file
while IFS= read -r f; do
  is_git_config "$f" && hook_deny "$f $reason"
done < <(
  printf '%s' "$HOOK_BARE" | rg -o -r '$1' '>{1,2}\s*([^\s;&|<>()]+)'
  printf '%s' "$HOOK_BARE" | rg -o -r '$1' '(?:^|[;&|(]\s*)tee\s+(?:-a\s+)?([^\s;&|<>()]+)'
)

# any other command naming a git config file, unless it only reads it
while IFS= read -r segment; do
  read -r cmd args <<<"$segment"
  case "$cmd" in cat | head | tail | less | bat | rg | grep | wc | diff | stat | ls | file | git) continue ;; esac
  f=$(printf '%s' "$args" | rg -o '(?:^|[^\w.])\.git/(?:[^/\s,()]+/)*config(?:\.worktree)?\b' | head -n 1)
  [ -z "$f" ] || hook_deny "${f#[^.]} $reason"
done < <(printf '%s' "$HOOK_BARE" | rg -o -r '$1' '(?:^|[;&|]\s*)(?:sudo\s+)?([^;&|]+)')

# a script, including a heredoc body, that names a git config file
printf '%s' "$HOOK_COMMAND" | rg -q '\b(python3?|node|ruby|perl)\b' &&
  printf '%s' "$HOOK_COMMAND" | rg -q '(?:^|[^\w.])\.git/(?:[^/\s,()]+/)*config(?:\.worktree)?\b' &&
  hook_deny 'This script names a git config file. Change git config with `git config`, and read it with Read or `git config --list --show-origin`.'

exit 0

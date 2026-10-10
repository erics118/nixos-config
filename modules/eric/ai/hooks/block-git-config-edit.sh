#!/usr/bin/env bash
# shellcheck disable=SC2016
# block direct writes to a repo's git config files, so config changes go through `git config`,
# where block-agent-commit.sh keeps agents from setting the eric-agent keys
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
source "$(dirname "$0")/lib.sh"

hook_require jq rg shfmt
HOOK_INPUT=$(cat)
reason='is a git config file. Change git config with `git config`, and read it with Read or `git config --list --show-origin`.'

# .git/config, config or config.worktree under .git/worktrees or .git/modules, and the global ~/.gitconfig or ~/.config/git/config
is_git_config() {
  printf '%s' "$1" | rg -q '(?:^|[/=])(?:\.git/(?:[^/\s]+/)*config(?:\.worktree)?|\.gitconfig|\.config/git/config)$'
}

file=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
if [ -n "$file" ]; then
  is_git_config "$file" && hook_deny "$file $reason"
  exit 0
fi

HOOK_COMMAND=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$HOOK_COMMAND" ] || exit 0
hook_parse_command

# ... > file, ... >> file, or tee file
while IFS= read -r f; do
  is_git_config "$f" && hook_deny "$f $reason"
done < <(hook_each 'writes')

# any other command naming a git config file, unless it only reads it
f=$(hook_each '
  select((.wrapper | not) and (tool | IN("cat", "head", "tail", "less", "bat", "rg", "grep", "wc", "diff", "stat", "ls", "file", "git") | not)) |
  .argv[1:][] | capture("(?:^|[^\\w.])(?<f>\\.git/(?:[^/\\s,()]+/)*config(?:\\.worktree)?|\\.gitconfig|\\.config/git/config)\\b").f
' | head -n 1)
[ -z "$f" ] || hook_deny "$f $reason"

# a script, including a heredoc body, that names a git config file
printf '%s' "$HOOK_COMMAND" | rg -q '\b(python3?|node|ruby|perl)\b' &&
  printf '%s' "$HOOK_COMMAND" | rg -q '(?:^|[^\w.])(?:\.git/(?:[^/\s,()]+/)*config(?:\.worktree)?|\.gitconfig|\.config/git/config)\b' &&
  hook_deny 'This script names a git config file. Change git config with `git config`, and read it with Read or `git config --list --show-origin`.'

exit 0

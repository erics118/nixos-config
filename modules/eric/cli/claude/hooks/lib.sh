#!/usr/bin/env bash
# shared helpers for PreToolUse/PostToolUse hooks. source, don't run directly:
#   source "$HOME/.claude/hooks/lib.sh"

# reads stdin once. sets $HOOK_INPUT (raw json) and $HOOK_COMMAND (tool_input.command).
# exits 0 (no-op) if there's no command to inspect.
hook_read_command() {
  HOOK_INPUT=$(cat)
  HOOK_COMMAND=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
  [ -n "$HOOK_COMMAND" ] || exit 0
}

# same, for Write/Edit's tool_input.file_path. sets $HOOK_INPUT and $HOOK_FILE.
hook_read_file_path() {
  HOOK_INPUT=$(cat)
  HOOK_FILE=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
  [ -n "$HOOK_FILE" ] || exit 0
}

# print a PreToolUse deny decision with the given reason, then exit.
hook_deny() {
  jq -cn --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"deny", permissionDecisionReason:$reason}}'
  exit 0
}

# print an updated tool_input.command (requires hook_read_command to have run first), then exit.
hook_update_command() {
  printf '%s' "$HOOK_INPUT" | jq -c --arg cmd "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse", updatedInput:(.tool_input | .command=$cmd)}}'
  exit 0
}

# print an updated tool_input.file_path (requires hook_read_file_path to have run first), then exit.
hook_update_file_path() {
  printf '%s' "$HOOK_INPUT" | jq -c --arg path "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse", updatedInput:(.tool_input | .file_path=$path)}}'
  exit 0
}

#!/usr/bin/env bash
# shared helpers for PreToolUse/PostToolUse hooks. source, don't run directly:
#   source "$(dirname "$0")/lib.sh"

# fail closed when a dependency is missing. these guards are the only gate under
# defaultMode auto, so a hook that cannot run must block rather than silently allow.
# exit 2 blocks the call and feeds stderr back, which works without jq.
hook_require() {
  for b in "$@"; do
    command -v "$b" >/dev/null 2>&1 && continue
    printf 'guard hook cannot run: %s is not on PATH, so the command was not checked.\n' "$b" >&2
    exit 2
  done
}

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

# directory a command runs in: the hook's cwd, or the target of a leading `cd DIR &&` or `cd DIR;`.
# sets $HOOK_DIR (requires hook_read_command to have run first).
hook_command_dir() {
  HOOK_DIR=$(printf '%s' "$HOOK_INPUT" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$HOOK_DIR" ] || HOOK_DIR=$PWD
  local to
  to=$(printf '%s' "$HOOK_COMMAND" | rg -o -r '$1' '^\s*\(?\s*cd\s+([^\s;&]+)\s*(&&|;)' | head -n 1)
  [ -n "$to" ] || return 0
  to=${to/#\~/$HOME}
  case "$to" in /*) HOOK_DIR=$to ;; *) HOOK_DIR=$HOOK_DIR/$to ;; esac
}

# the command on one line with heredoc bodies and quoted text containing spaces removed,
# and other quote marks dropped, so guards match what runs, not text it searches or writes.
# sets $HOOK_BARE (requires hook_read_command to have run first).
hook_bare_command() {
  HOOK_BARE=$(printf '%s\n' "$HOOK_COMMAND" | awk '
    body { t = $0; gsub(/^[ \t]+|[ \t]+$/, "", t); if (t == delim) body = 0; next }
    { print }
    match($0, /<<-?[ \t]*["\x27]?[A-Za-z_][A-Za-z0-9_]*/) && substr($0, RSTART - 1, 1) != "<" {
      delim = substr($0, RSTART, RLENGTH)
      sub(/^<<-?[ \t]*["\x27]?/, "", delim)
      body = 1
    }' | tr '\n' ';' | sed 's/;$//' | awk -v sq="'" '
    # walk quotes left to right so each opening quote pairs with its own closing one
    {
      out = ""; q = ""; buf = ""
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (q == "") {
          if (c == "\"" || c == sq) { q = c; buf = "" } else out = out c
        } else if (c == q) {
          # quoted separators do not split the command, so they must not look like they do
          if (buf !~ /[[:space:]]/) { gsub(/[;&|()]/, "_", buf); out = out buf }
          q = ""
        } else buf = buf c
      }
      if (q != "") out = out q buf
      sub(/[[:space:]]+$/, "", out)
      print out
    }')
}

# regex for `git` where a command starts, with env assignments, a command/env/exec prefix,
# a path, and global options allowed. append the subcommand, then match it against $HOOK_BARE.
HOOK_PREFIX='(?:^|[;&|(]\s*)(?:(?:\w+=\S*|command|env|exec)\s+)*(?:\S*/)?'
HOOK_GIT="${HOOK_PREFIX}"'git(?:\s+(?:-[cC]\s+\S+|--\S+))*\s+'

# regex for the end of a subcommand word. \b would also end at a dash, so merge would match merge-base.
HOOK_END='(?:\s|$|[;&|)])'

# true when the path, relative to $HOOK_DIR, is an existing file that git tracks.
hook_tracked() {
  local f=${1/#\~/$HOME}
  case "$f" in /*) ;; *) f=$HOOK_DIR/$f ;; esac
  [ -f "$f" ] && git -C "$(dirname "$f")" ls-files --error-unmatch -- "$(basename "$f")" >/dev/null 2>&1
}

# print a PreToolUse deny decision with the given reason, then exit.
hook_deny() {
  jq -cn --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"deny", permissionDecisionReason:$reason}}'
  exit 0
}

# print a PreToolUse ask decision with the given reason, then exit. forces the normal
# permission prompt instead of refusing outright.
hook_ask() {
  jq -cn --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"ask", permissionDecisionReason:$reason}}'
  exit 0
}

# print an updated tool_input.command (requires hook_read_command to have run first), then exit.
hook_update_command() {
  printf '%s' "$HOOK_INPUT" | jq -c --arg cmd "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse", updatedInput:(.tool_input | .command=$cmd)}}'
  exit 0
}

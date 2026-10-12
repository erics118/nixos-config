#!/usr/bin/env bash
# run the guard checks for one tool call and print one combined decision
# usage: guard.sh pre|post claude|codex|pi [check...], with the hook event json on stdin
# named checks replace the tool's default list, so a test can run one check
set -u
hooks=$(dirname "$0")
# shellcheck source-path=SCRIPTDIR source=lib.sh
source "$hooks/lib.sh"

event=$1 harness=$2
shift 2
hook_require jq
HOOK_INPUT=$(cat)
HOOK_COMMAND=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.command // empty')
HOOK_CALLS=
checks=("$@")
if [ ${#checks[@]} -eq 0 ]; then
  case "$event:$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_name // empty')" in
  pre:Bash | pre:Monitor)
    checks=(git-add-before-nix strip-claude-attribution block-global-search block-symlink-clobber ask-dangerous-git
      block-agent-commit block-agent-push block-git-config-edit block-shell-edit block-sudo-probe block-exec-flags)
    ;;
  pre:Read) checks=(deny-symlink-path) ;;
  pre:Write) checks=(deny-symlink-path block-smart-punct block-git-config-edit block-write-tracked) ;;
  pre:Edit) checks=(deny-symlink-path block-smart-punct block-git-config-edit) ;;
  post:Write | post:Edit) checks=(treefmt-on-edit warn-comment-block) ;;
  *) exit 0 ;;
  esac
fi

# a post check warns the model with stderr and exit 2. the tool already ran, so nothing blocks
if [ "$event" = post ]; then
  rc=0
  for c in "${checks[@]}"; do
    # shellcheck disable=SC1090
    (source "$hooks/checks/$c.sh") || rc=$?
  done
  exit "$rc"
fi

hook_require git rg realpath
if [ -n "$HOOK_COMMAND" ]; then
  hook_require shfmt
  hook_parse_command
fi

# each check runs in a subshell, so its exit ends only that check. a deny wins at once
ask='' updated=''
for c in "${checks[@]}"; do
  # shellcheck disable=SC1090
  out=$(source "$hooks/checks/$c.sh" 2>/dev/null) ||
    hook_deny "The guard check $c failed with exit $?, so the command was not checked."
  [ -n "$out" ] || continue
  reason=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty')
  case $(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty') in
  deny) hook_deny "${reason:-$c blocked this.}" ;;
  ask) ask=${ask:-${reason:-$c asks for approval.}} ;;
  esac
  updated=$(printf '%s' "$out" | jq -r --arg u "$updated" '.hookSpecificOutput.updatedInput.command // $u')
done

# codex runs an ask as allow and applies a rewrite only with an allow
if [ "$harness" = codex ]; then
  [ -z "$ask" ] || hook_deny "$ask Codex cannot ask for approval, so this was denied. Tell the user what to run."
  exit 0
fi
[ -n "$ask$updated" ] || exit 0
printf '%s' "$HOOK_INPUT" | jq -c --arg ask "$ask" --arg cmd "$updated" '{hookSpecificOutput: ({hookEventName: "PreToolUse"} +
  (if $ask == "" then {} else {permissionDecision: "ask", permissionDecisionReason: $ask} end) +
  (if $cmd == "" then {} else {updatedInput: (.tool_input | .command = $cmd)} end))}'

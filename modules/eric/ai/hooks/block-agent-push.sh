#!/usr/bin/env bash
# deny agent pushes by default. `eric-agent.push=ask` requests confirmation.
# `eric-agent.push=on` allows pushes. GitHub writes remain user-only
set -u
source "$(dirname "$0")/lib.sh"

hook_require rg jq awk
hook_read_command
hook_command_dir
hook_bare_command

GH="${HOOK_PREFIX}gh\\s+"

# a -c alias can run push under another name
# the raw command keeps a quoted alias value that $HOOK_BARE drops
printf '%s\n%s' "$HOOK_COMMAND" "$HOOK_BARE" | rg -qi "${HOOK_PREFIX}git\\s[^;&|]*-c\\s*[\"']?alias\\." &&
  hook_deny 'Agents never define git aliases with -c, since an alias can wrap push or commit.'

match=$(printf '%s' "$HOOK_BARE" | rg -o "${HOOK_GIT}push${HOOK_END}" | head -n 1)
if [ -n "$match" ]; then
  dir=$(printf '%s' "$match" | rg -o -r '$1' '\s-C\s+(\S+)' | head -n 1)
  dir=${dir/#\~/$HOME}
  case "$dir" in '') dir=$HOOK_DIR ;; /*) ;; *) dir=$HOOK_DIR/$dir ;; esac
  case "$(git -C "$dir" config --get eric-agent.push 2>/dev/null)" in
  on) exit 0 ;;
  ask)
    # codex runs a hook's ask as allow, so deny there
    printf '%s' "$HOOK_INPUT" | jq -e 'has("turn_id") or (.transcript_path // "" | contains("/.codex/"))' >/dev/null &&
      hook_deny 'Agent pushes need approval in this repo, and Codex cannot prompt. Tell the user the work is ready so they push it.'
    hook_ask 'Agent pushes need approval in this repo. Approve this push, or push it yourself.'
    ;;
  esac
  hook_deny 'Agent pushes are off in this repo. Tell the user the work is ready so they push it.'
fi

# gh is read-only: allow only known reads, so new write commands are denied too
while read -r group sub; do
  case "$group $sub" in
  'api '* | 'search '* | 'status ' | 'repo clone' | *' view' | *' list' | *' status' | *' diff' | *' checks') continue ;;
  esac
  hook_deny "Agents use gh read-only, and gh $group $sub is not a known read. Tell the user what to run."
done < <(printf '%s' "$HOOK_BARE" | rg -o -r '$1 $2' "${GH}(\S+)(?:\s+([^\s;&|)]+))?")

printf '%s' "$HOOK_BARE" | rg -q "${GH}[^;&|]*--show-token" &&
  hook_deny 'Agents never print the GitHub token.'

# gh api writes: a non-GET method, or fields, which make gh default to POST
printf '%s' "$HOOK_BARE" | rg -o "${GH}api\s[^;&|]*" |
  rg -qi '\s(?:-X\s*|--method[\s=]\s*)(?:POST|PUT|PATCH|DELETE)\b|\s(?:-[fF]|(?:--field|--raw-field|--input)[\s=])' &&
  hook_deny 'Agents never write to GitHub through gh api. Use read-only gh api calls, or tell the user what to run.'

exit 0

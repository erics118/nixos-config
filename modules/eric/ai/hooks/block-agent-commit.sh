#!/usr/bin/env bash
# gate agent commits on `git config eric-agent.commit`: off (default), ask, branch (not main or master), or on.
# only the user sets eric-agent keys, so agents may not write them
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
source "$(dirname "$0")/lib.sh"

hook_require jq git shfmt
hook_read_command
hook_parse_command
hook_command_dir

# each config command naming an eric-agent key, an alias, or an include must itself be a read
hook_any 'git | .[0] == "config" and any(.[]; ascii_downcase | test("eric-agent|^(alias|include|includeif)\\.|^(-e|--edit|edit)$")) and
  (any(.[]; IN("--get", "--get-regexp", "get")) | not)' &&
  hook_deny 'Only the user sets eric-agent keys, git aliases, and git includes, since an alias or include can wrap push or commit.'

# a -c alias can run commit under another name
hook_any 'git_alias' &&
  hook_deny 'Agents never define git aliases or includes with -c or --config-env, since an alias can wrap push or commit.'
hook_deny_git_env

# pull commits unless it only fast-forwards. --abort and --quit only back out
hook_gate_dirs 'git | ((.[0] | IN("commit", "commit-tree", "merge", "revert", "cherry-pick", "am", "subtree")) or
  (.[0] == "pull" and (any(.[]; . == "--ff-only") | not))) and
  ((.[0] | IN("merge", "revert", "cherry-pick", "am")) and any(.[]; IN("--abort", "--quit")) | not) and
  (.[0] == "commit" and git_dry_run | not)'

ask=
while IFS= read -r dir; do
  [ -n "$dir" ] || continue
  case "$(git -C "$dir" config --get eric-agent.commit 2>/dev/null)" in
  on) ;;
  branch)
    case "$(git -C "$dir" symbolic-ref --short -q HEAD)" in
    main | master | '') hook_deny 'Agent commits are allowed only on a feature branch in this repo. Create one, or tell the user the work is ready.' ;;
    esac
    ;;
  ask) ask=1 ;;
  *) hook_deny 'Agent commits are off in this repo. Tell the user the work is ready so they commit it.' ;;
  esac
done <<<"$HOOK_GATE_DIRS"

if [ -n "$ask" ]; then
  hook_is_codex &&
    hook_deny 'Agent commits need approval in this repo, and Codex cannot prompt. Tell the user the work is ready so they commit it.'
  hook_ask 'Agent commits need approval in this repo. Approve this commit, or deny it and commit yourself.'
fi
exit 0

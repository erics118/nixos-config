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

# each config command naming an eric-agent key must itself be a read
hook_any 'git | .[0] == "config" and any(.[]; contains("eric-agent")) and (any(.[]; IN("--get", "--get-regexp", "get")) | not)' &&
  hook_deny 'Only the user sets eric-agent keys.'

# a -c alias can run commit under another name
hook_any 'git_alias' &&
  hook_deny 'Agents never define git aliases with -c, since an alias can wrap push or commit.'

dir=$(hook_each 'select(git | .[0] | IN("commit", "merge", "revert", "cherry-pick", "am")) | "dir:" + git_dir' | head -n 1)
[ -n "$dir" ] || exit 0
dir=$(hook_resolve "${dir#dir:}")

case "$(git -C "$dir" config --get eric-agent.commit 2>/dev/null)" in
on) exit 0 ;;
branch)
  case "$(git -C "$dir" symbolic-ref --short -q HEAD)" in
  main | master | '') hook_deny 'Agent commits are allowed only on a feature branch in this repo. Create one, or tell the user the work is ready.' ;;
  esac
  exit 0
  ;;
ask)
  hook_is_codex &&
    hook_deny 'Agent commits need approval in this repo, and Codex cannot prompt. Tell the user the work is ready so they commit it.'
  hook_ask 'Agent commits need approval in this repo. Approve this commit, or deny it and commit yourself.'
  ;;
esac
hook_deny 'Agent commits are off in this repo. Tell the user the work is ready so they commit it.'

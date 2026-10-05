#!/usr/bin/env bash
# shellcheck disable=SC2016
# prompt before git commands that rewrite history or discard uncommitted work.
# asks rather than denies, so anything genuinely wanted is one confirmation away.
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
source "$(dirname "$0")/lib.sh"

hook_require jq shfmt
hook_read_command
hook_parse_command

hook_any '
  def has($xs): any(.[1:][]; IN($xs[]));
  def dangerous: .[0] as $sub | .[1:] as $args |
    ($sub | IN("rebase", "reset", "filter-branch")) or
    ($sub == "reflog" and .[1] == "expire") or
    ($sub == "clean" and any($args[]; test("^-[a-zA-Z]*f") or . == "--force")) or
    ($sub == "stash" and (.[1] | IN("drop", "clear"))) or
    ($sub == "checkout" and (has(["-f", "-B", "--force", "."]) or ($args | index(["--"]) as $i | $i != null and $i < ($args | length) - 1))) or
    ($sub == "switch" and has(["-f", "-C", "--force", "--force-create", "--discard-changes"])) or
    ($sub == "worktree" and .[1] == "remove" and has(["-f", "--force"])) or
    ($sub == "branch" and (has(["-D"]) or (has(["-d", "--delete"]) and has(["-f", "--force"])))) or
    # restore discards worktree changes unless it only unstages with --staged and no --worktree
    ($sub == "restore" and (any($args[]; . == "--staged" or test("^-[a-zA-Z]*S")) and
      (any($args[]; . == "--worktree" or test("^-[a-zA-Z]*W")) | not) | not));
  git | dangerous
' &&
  hook_ask 'This git command rewrites history or discards uncommitted work. Approve it, or run it yourself.'

exit 0

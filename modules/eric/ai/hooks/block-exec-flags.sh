#!/usr/bin/env bash
# shellcheck disable=SC2016
# block the flags that turn an allowlisted read-only tool into a writer or a launcher.
# the agents approve fd, rg, sort, tree, git diff, and git log without asking, so these
# would run an arbitrary command or write a file with no prompt
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
source "$(dirname "$0")/lib.sh"

hook_require jq shfmt
hook_read_command
hook_parse_command

hook_any '
  (tool == "fd" and any(.argv[1:][]; IN("-x", "-X") or startswith("--exec"))) or
  (tool == "rg" and any(.argv[1:][]; . == "--pre" or startswith("--pre="))) or
  (tool == "sort" and any(.argv[1:][]; test("^-[bdfghiMnRrsuVcCz]*o") or . == "--output" or startswith("--output="))) or
  (tool == "tree" and any(.argv[1:][]; . == "-o")) or
  ([git | select(.[0] | IN("diff", "log", "show", "whatchanged")) | . as $a | ($a | index(["--"]) // length) as $end |
    any($a[:$end][]; . == "--output" or startswith("--output="))] | any)
' &&
  hook_deny 'fd -x/--exec, rg --pre, sort -o, tree -o, and git diff/log/show --output run a command or write a file, which their read-only approval does not cover. Run the command or the write as its own step, such as a shell loop over the fd output.'

exit 0

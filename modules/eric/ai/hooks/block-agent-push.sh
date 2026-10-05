#!/usr/bin/env bash
# shellcheck disable=SC2016
# deny agent pushes by default. `eric-agent.push=ask` requests confirmation.
# `eric-agent.push=on` allows pushes. GitHub writes remain user-only
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
source "$(dirname "$0")/lib.sh"

hook_require jq git shfmt
hook_read_command
hook_parse_command
hook_command_dir

# a -c alias can run push under another name
hook_any 'git_alias' &&
  hook_deny 'Agents never define git aliases with -c, since an alias can wrap push or commit.'

dir=$(hook_each 'select(git | .[0] == "push") | "dir:" + git_dir' | head -n 1)
if [ -n "$dir" ]; then
  dir=$(hook_resolve "${dir#dir:}")
  case "$(git -C "$dir" config --get eric-agent.push 2>/dev/null)" in
  on) exit 0 ;;
  ask)
    hook_is_codex &&
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
done < <(hook_each 'select(tool == "gh") | "\(.argv[1] // "") \(.argv[2] // "")"')

hook_any 'tool == "gh" and any(.argv[]; . == "--show-token")' &&
  hook_deny 'Agents never print the GitHub token.'

# gh api writes: a non-GET method, or fields, which make gh default to POST
hook_any '
  tool == "gh" and .argv[1] == "api" and (.argv as $a | any(range(2; $a | length) as $i | $a[$i] |
    (ascii_upcase | test("^(-X|--METHOD=?)(POST|PUT|PATCH|DELETE)$")) or
    (IN("-X", "--method") and ($a[$i + 1] // "" | ascii_upcase | IN("POST", "PUT", "PATCH", "DELETE"))) or
    test("^-[fF]|^--(field|raw-field|input)(=|$)"); .))
' &&
  hook_deny 'Agents never write to GitHub through gh api. Use read-only gh api calls, or tell the user what to run.'

exit 0

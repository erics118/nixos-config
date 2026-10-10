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
  hook_deny 'Agents never define git aliases or includes with -c or --config-env, since an alias can wrap push or commit.'
hook_deny_git_env

hook_gate_dirs 'git | ((.[0] | IN("push", "send-pack")) or ((.[0] | IN("subtree", "lfs")) and any(.[1:][]; . == "push"))) and
  (.[0] == "push" and git_dry_run | not)'

ask=
while IFS= read -r dir; do
  [ -n "$dir" ] || continue
  case "$(git -C "$dir" config --get eric-agent.push 2>/dev/null)" in
  on) ;;
  ask) ask=1 ;;
  *) hook_deny 'Agent pushes are off in this repo. Tell the user the work is ready so they push it.' ;;
  esac
done <<<"$HOOK_GATE_DIRS"

# gh is read-only: allow only known reads, so new write commands are denied too
while read -r group sub; do
  case "$group $sub" in
  'api '* | 'search '* | 'status ' | 'repo clone' | 'run watch' | *' view' | *' list' | *' status' | *' diff' | *' checks') continue ;;
  esac
  hook_deny "Agents use gh read-only, and gh $group $sub is not a known read. Tell the user what to run."
done < <(hook_each 'select(tool == "gh") | "\(.argv[1] // "") \(.argv[2] // "")"')

hook_any 'tool == "gh" and any(.argv[]; . == "--show-token")' &&
  hook_deny 'Agents never print the GitHub token.'

# gh api writes: a method other than GET or HEAD, or fields with no method, which make gh default to POST
# graphql always posts, so a literal query with no mutation reads
# a $ is denied too, since a shell expansion and a graphql variable look the same here
hook_any '
  def graphql_read: .argv[2] == "graphql" and (.argv as $a | [range(3; $a | length) as $i | $a[$i] |
    if IN("-f", "-F", "--field", "--raw-field") then ($a[$i + 1] // "") else (capture("^(-[fF]|--field=|--raw-field=)(?<v>.+)").v) end |
    select(startswith("query=")) | .[6:]] as $q |
    $q != [] and all($q[]; test("^\\s*(query\\b|\\{)") and (contains("$") | not) and (test("mutation"; "i") | not)) and
    all($a[]; test("^--input(=|$)") | not));
  tool == "gh" and .argv[1] == "api" and (.argv as $a | [range(2; $a | length) as $i | $a[$i] | ascii_upcase |
    if IN("-X", "--METHOD") then ($a[$i + 1] // "" | ascii_upcase) else (capture("^(-X|--METHOD=)(?<m>.+)").m) end] as $m |
    any($m[]; IN("GET", "HEAD") | not) or
    ($m == [] and any($a[]; test("^-[fF]|^--(field|raw-field|input)(=|$)")) and (graphql_read | not)))
' &&
  hook_deny 'Agents never write to GitHub through gh api. Use read-only gh api calls, or tell the user what to run. A graphql read must pass one literal query with -f query=..., with values inlined and no $ variables.'

if [ -n "$ask" ]; then
  hook_is_codex &&
    hook_deny 'Agent pushes need approval in this repo, and Codex cannot prompt. Tell the user the work is ready so they push it.'
  hook_ask 'Agent pushes need approval in this repo. Approve this push, or push it yourself.'
fi
exit 0

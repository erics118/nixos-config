#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

hooks=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$hooks/../../../../" && pwd)
settings="$root/modules/eric/ai/claude/settings.json"
repo=$(mktemp -d)
trap 'rm -rf "$repo"' EXIT

# guard.sh runs agent-guard from PATH, so build the working tree's copy first
(cd "$hooks/../guard" && go build -o "$repo/guard-bin/agent-guard" .)
PATH=$repo/guard-bin:$PATH

tested=()

json() {
  jq -cn --arg cwd "$1" --arg command "$2" '{cwd:$cwd,tool_input:{command:$command}}'
}

expect_allow() {
  local name=$1 script=$2 input=$3 output
  tested+=("$script")
  output=$(cd "$repo" && printf '%s' "$input" | "$hooks/$script")
  [ -z "$output" ] || {
    printf 'FAIL %s: %s\n' "$name" "$output"
    exit 1
  }
  printf 'ok %s\n' "$name"
}

# guard.sh runs the checks, whose cases are the go tests in guard/
json "$repo" 'rm f' | "$hooks/guard.sh" pre claude block-rm | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null || {
  printf 'FAIL guard.sh did not run a check\n'
  exit 1
}
printf 'ok guard runs a check\n'
# a missing agent-guard must exit 2, since claude code and codex run the command on any other code
set +e
json "$repo" 'ls' | PATH=/usr/bin:/bin "$hooks/guard.sh" pre claude >/dev/null 2>&1
status=$?
set -e
[ "$status" -eq 2 ] || {
  printf 'FAIL guard.sh exited %s without agent-guard\n' "$status"
  exit 1
}
printf 'ok guard fails closed without agent-guard\n'
json "$repo" 'ls' | "$hooks/guard.sh" pre claude no-such-check | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null || {
  printf 'FAIL guard.sh let an unknown check pass\n'
  exit 1
}
printf 'ok guard fails closed on an unknown check\n'

# a stub tmux names a plain file as the pane's tty, so the test never rings a real bell
mkdir "$repo/tmux-bin"
printf '#!/bin/sh\ncase "$*" in *pane_tty*) echo "%s/pane-tty" ;; esac\n' "$repo" >"$repo/tmux-bin/tmux"
chmod +x "$repo/tmux-bin/tmux"
: >"$repo/pane-tty"
TMUX_PANE='' expect_allow tmux-bell-outside-tmux tmux-bell.sh '{}'
[ ! -s "$repo/pane-tty" ] || {
  printf 'FAIL tmux-bell rang outside tmux\n'
  exit 1
}
PATH=$repo/tmux-bin:$PATH TMUX_PANE=%1 expect_allow tmux-bell tmux-bell.sh '{}'
[ "$(cat "$repo/pane-tty")" = $'\a' ] || {
  printf 'FAIL tmux-bell did not ring the pane tty\n'
  exit 1
}

tested+=(tmux-agent-resume.sh)
# a private tmux server, with timeout standing in for an agent the pane's shell starts
if command -v tmux >/dev/null; then
  resume_tmux() { tmux -L "agent-resume-test-$$" -f /dev/null "$@"; }
  # each pane signals once its hook has run, then stays open so its options can be read
  resume_tmux new -d -s direct "timeout 5 '$hooks/tmux-agent-resume.sh' claude <<<'{\"session_id\":\"abc\"}'; tmux wait-for -S direct; sleep 5"
  resume_tmux new -d -s nested "timeout 5 timeout 5 '$hooks/tmux-agent-resume.sh' claude <<<'{\"session_id\":\"abc\"}'; tmux wait-for -S nested; sleep 5"
  # the agent is the pane's own process, as in an agent-side split
  resume_tmux new -d -s side "exec timeout 5 bash -c \"'$hooks/tmux-agent-resume.sh' claude <<<'{\\\"session_id\\\":\\\"abc\\\"}'; tmux wait-for -S side; sleep 5\""
  resume_tmux wait-for direct
  resume_tmux wait-for nested
  resume_tmux wait-for side
  top=$(resume_tmux show -pqv -t =direct: @agent_resume)
  nested=$(resume_tmux show -pqv -t =nested: @agent_resume)
  side=$(resume_tmux show -pqv -t =side: @agent_resume)
  resume_tmux kill-server
  [ "$top" = 'claude --resume abc' ] || {
    printf 'FAIL tmux-agent-resume recorded %q\n' "$top"
    exit 1
  }
  printf 'ok tmux-agent-resume\n'
  [ -z "$nested" ] || {
    printf 'FAIL tmux-agent-resume recorded a nested agent: %q\n' "$nested"
    exit 1
  }
  printf 'ok tmux-agent-resume-nested\n'
  [ "$side" = 'claude --resume abc' ] || {
    printf 'FAIL tmux-agent-resume recorded %q for an agent-side pane\n' "$side"
    exit 1
  }
  printf 'ok tmux-agent-resume-side\n'
else
  printf 'skip tmux-agent-resume: tmux is not on PATH\n'
fi

tested+=(reminders.sh)
rem_home=$repo/reminders-home
rem_repo=$repo/reminders-repo
mkdir -p "$rem_home/.eric"
git init -q "$rem_repo"
[ -z "$(cd "$repo" && HOME=$rem_home "$hooks/reminders.sh" <<<'{}')" ] || {
  printf 'FAIL reminders printed with no lists\n'
  exit 1
}
printf 'ok reminders-empty\n'
printf -- '- global item\n' >"$rem_home/.eric/reminders.md"
mkdir "$rem_repo/.eric"
printf -- '- repo item\n' >"$rem_repo/.eric/reminders.md"
# a worktree reads its main repo's list
git -C "$rem_repo" worktree add -q "$repo/reminders-wt"
HOME=$rem_home "$hooks/reminders.sh" <<<"{\"cwd\":\"$repo/reminders-wt\"}" |
  jq -e --arg f "$rem_repo/.eric/reminders.md" '.hookSpecificOutput.additionalContext | contains("- global item") and contains("- repo item") and contains($f)' >/dev/null || {
  printf 'FAIL reminders did not show both lists from a worktree\n'
  exit 1
}
printf 'ok reminders-both\n'

# every script settings.json runs from this directory, since herdr installs its own by absolute path
# guard/checks_test.go covers every agent-guard check
configured=$(jq -r '.hooks | to_entries[] | .value[] | .hooks[] | .command | select(startswith("\"$HOME/.agents/hooks/"))' "$settings" |
  sed -E 's#.*/##; s/"//g; s/ .*//' | grep -vx guard.sh | sort -u)
covered=$(printf '%s\n' "${tested[@]}" | sort -u)
[ "$configured" = "$covered" ] || {
  printf 'configured hook coverage mismatch\nexpected:\n%s\ncovered:\n%s\n' "$configured" "$covered" >&2
  exit 1
}
printf 'all configured hooks covered\n'

# claude and pi agents need different frontmatter but must share one body
for pi_agent in "$root"/modules/eric/ai/pi/agents/*.md; do
  name=$(basename "$pi_agent")
  diff <(awk 'f >= 2; /^---$/ { f++ }' "$root/modules/eric/ai/claude/agents/$name") <(awk 'f >= 2; /^---$/ { f++ }' "$pi_agent") >/dev/null || {
    printf 'FAIL agent body: claude/agents/%s and pi/agents/%s differ\n' "$name" "$name"
    exit 1
  }
  printf 'ok agent body: %s\n' "$name"
done
# codex agents hold the same body in developer_instructions, naming skills as $skill
for codex_agent in "$root"/modules/eric/ai/codex/agents/*.toml; do
  name=$(basename "$codex_agent" .toml)
  diff <(awk 'f >= 2; /^---$/ { f++ }' "$root/modules/eric/ai/claude/agents/$name.md" | sed '/./,$!d') \
    <(awk '/^"""$/ { f = 0 } f; /^developer_instructions = """$/ { f = 1 }' "$codex_agent" | sed -E 's/\$([a-z-]+)/\1/g') >/dev/null || {
    printf 'FAIL agent body: claude/agents/%s.md and codex/agents/%s.toml differ\n' "$name" "$name"
    exit 1
  }
  printf 'ok agent body: codex %s\n' "$name"
done

# the inline SessionStart check stays quiet while every hook exists, and names one that is gone
startup_check=$(jq -r '.hooks.SessionStart[].hooks[].command | select(contains("guard hooks missing"))' "$settings")
check_home=$repo/check-home
mkdir -p "$check_home/.claude" "$check_home/.agents"
cp "$settings" "$check_home/.claude/settings.json"
ln -s "$hooks" "$check_home/.agents/hooks"
[ -n "$startup_check" ] && [ -z "$(HOME=$check_home bash -c "$startup_check")" ] || {
  printf 'FAIL session-start-hook-check: missing, or warned with every hook present\n'
  exit 1
}
rm "$check_home/.agents/hooks"
HOME=$check_home bash -c "$startup_check" | jq -e '.systemMessage | contains("guard.sh")' >/dev/null || {
  printf 'FAIL session-start-hook-check: did not name a missing hook\n'
  exit 1
}
printf 'ok session-start-hook-check\n'

rules="$root/modules/eric/ai/codex/rules/default.rules"
expect_rule() {
  local decision=$1 got
  shift
  got=$(codex execpolicy check --rules "$rules" "$@" | jq -r '.decision // "none"')
  [ "$got" = "$decision" ] || {
    printf 'FAIL codex rules: %s is %s, expected %s\n' "$*" "$got" "$decision"
    exit 1
  }
  printf 'ok codex-rules: %s -> %s\n' "$*" "$decision"
}
if command -v codex >/dev/null 2>&1; then
  expect_rule forbidden git push origin main
  expect_rule forbidden gh pr create
  expect_rule allow git status
  expect_rule allow rg foo .
  # nix develop -c runs any command, so it goes through the sandbox like other commands
  expect_rule none nix develop -c true
  expect_rule none git checkout main
else
  printf 'skip codex-rules: codex is not on PATH\n'
fi

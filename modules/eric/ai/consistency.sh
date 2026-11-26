#!/usr/bin/env bash
# checks that the agent config files agree with each other and with agent-guard, which must be on PATH.
# modules/checks.nix runs it as the agent-config check, so `just check` and CI both do
# usage: consistency.sh <the modules/eric/ai directory>
# shellcheck disable=SC2016
set -euo pipefail

# absolute, since the check links $ai/hooks into a temp home and a relative link target dangles there
ai=$(cd -- "$1" && pwd)
settings=$ai/claude/settings.json
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# the claude matchers name exactly the tools the checks run on, so a check on a new tool is never left unhooked
for event in pre post; do
  key=PreToolUse
  [ "$event" = pre ] || key=PostToolUse
  matcher=$(jq -r --arg k "$key" '.hooks[$k][].matcher' "$settings" | tr '|' '\n' | LC_ALL=C sort -u)
  [ "$matcher" = "$(agent-guard tools "$event")" ] || {
    printf 'FAIL the %s matcher names %s, but the checks run on %s\n' "$key" "$(tr '\n' ' ' <<<"$matcher")" "$(agent-guard tools "$event" | tr '\n' ' ')"
    exit 1
  }
done
printf 'ok matchers name the checked tools\n'

# the README names every check, so its list cannot fall behind guard/checks.go
while IFS= read -r check; do
  grep -qF -- "\`$check\`" "$ai/README.md" || {
    printf 'FAIL README.md does not name the check %s\n' "$check"
    exit 1
  }
done < <(agent-guard checks)
printf 'ok README names every check\n'

# block-eric-top keeps its own list of .eric entries, so it must name the same ones the global instructions list
guard_entries=$(grep -oE 'ericEntries = \[\]string\{[^}]*\}' "$ai/guard/block_eric_top.go" | grep -oE '"[^"]+"' | tr -d '"' | LC_ALL=C sort)
doc_entries=$(sed -n '/^- `\.eric\/`/,/^- /p' "$ai/AGENTS-global.md" | grep '^  - `' | grep -oE '(^  - |, )`[^`/]+' | sed -E 's/.*`//' | LC_ALL=C sort)
[ -n "$guard_entries" ] && [ "$guard_entries" = "$doc_entries" ] || {
  printf 'FAIL .eric entries: block_eric_top.go names %s, AGENTS-global.md lists %s\n' "$(tr '\n' ' ' <<<"$guard_entries")" "$(tr '\n' ' ' <<<"$doc_entries")"
  exit 1
}
printf 'ok .eric entries match block-eric-top\n'

# claude and pi agents need different frontmatter but must share one body
for pi_agent in "$ai"/pi/agents/*.md; do
  name=$(basename "$pi_agent")
  diff <(awk 'f >= 2; /^---$/ { f++ }' "$ai/claude/agents/$name") <(awk 'f >= 2; /^---$/ { f++ }' "$pi_agent") >/dev/null || {
    printf 'FAIL agent body: claude/agents/%s and pi/agents/%s differ\n' "$name" "$name"
    exit 1
  }
  printf 'ok agent body: %s\n' "$name"
done
# codex agents hold the same body in developer_instructions, naming skills as $skill
for codex_agent in "$ai"/codex/agents/*.toml; do
  name=$(basename "$codex_agent" .toml)
  diff <(awk 'f >= 2; /^---$/ { f++ }' "$ai/claude/agents/$name.md" | sed '/./,$!d') \
    <(awk '/^"""$/ { f = 0 } f; /^developer_instructions = """$/ { f = 1 }' "$codex_agent" | sed -E 's/\$([a-z-]+)/\1/g') >/dev/null || {
    printf 'FAIL agent body: claude/agents/%s.md and codex/agents/%s.toml differ\n' "$name" "$name"
    exit 1
  }
  printf 'ok agent body: codex %s\n' "$name"
done

# the inline SessionStart check stays quiet while every hook exists, and names one that is gone
startup_check=$(jq -r '.hooks.SessionStart[].hooks[].command | select(contains("guard hooks missing"))' "$settings")
check_home=$work/check-home
mkdir -p "$check_home/.claude" "$check_home/.agents"
cp "$settings" "$check_home/.claude/settings.json"
ln -s "$ai/hooks" "$check_home/.agents/hooks"
[ -n "$startup_check" ] && [ -z "$(HOME=$check_home bash -c "$startup_check")" ] || {
  printf 'FAIL session-start-hook-check: missing, or warned with every hook present\n'
  exit 1
}
rm "$check_home/.agents/hooks"
HOME=$check_home bash -c "$startup_check" | jq -e '.systemMessage | contains("tmux-bell.sh")' >/dev/null || {
  printf 'FAIL session-start-hook-check: did not name a missing hook\n'
  exit 1
}
printf 'ok session-start-hook-check\n'

# with agent-guard off PATH, sh exits 127, which the harnesses treat as non-blocking, so the commands turn it into a block
guard_cmds=$(jq -r '.hooks[][].hooks[].command // empty | select(startswith("agent-guard "))' "$settings" "$ai/codex/hooks.json")
[ "$(printf '%s\n' "$guard_cmds" | grep -c .)" -eq 3 ] || {
  printf 'FAIL expected the claude pre and post and the codex pre guard commands, found:\n%s\n' "$guard_cmds"
  exit 1
}
while IFS= read -r cmd; do
  set +e
  PATH=/usr/bin:/bin sh -c "$cmd" </dev/null >/dev/null 2>&1
  status=$?
  set -e
  [ "$status" -eq 2 ] || {
    printf 'FAIL guard command exited %s without agent-guard: %s\n' "$status" "$cmd"
    exit 1
  }
done <<<"$guard_cmds"
printf 'ok guard-command-fails-closed\n'

# a post check warns with exit 2, which the post command passes through without claiming the guard did not run
mkdir -p "$check_home/bin"
printf '#!/bin/sh\necho warned >&2\nexit 2\n' >"$check_home/bin/agent-guard"
chmod +x "$check_home/bin/agent-guard"
post_cmd=$(jq -r '.hooks.PostToolUse[].hooks[].command | select(startswith("agent-guard "))' "$settings")
set +e
post_err=$(PATH=$check_home/bin:/usr/bin:/bin sh -c "$post_cmd" </dev/null 2>&1 >/dev/null)
status=$?
set -e
[ "$status" -eq 2 ] && [ "$post_err" = warned ] || {
  printf 'FAIL post command on a warning: exit %s, stderr %q\n' "$status" "$post_err"
  exit 1
}
printf 'ok post-command-passes-warning\n'

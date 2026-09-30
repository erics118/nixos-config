#!/usr/bin/env bash
set -euo pipefail

hooks=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$hooks/../../../../" && pwd)
settings="$root/modules/eric/ai/claude/settings.json"
repo=$(mktemp -d)
trap 'rm -rf "$repo"' EXIT

tested=()

json() {
  jq -cn --arg cwd "$1" --arg command "$2" --arg file_path "${3:-}" --arg content "${4:-}" \
    '{cwd:$cwd,tool_input:({command:$command} + if $file_path == "" then {} else {file_path:$file_path,content:$content} end)}'
}

run_hook() {
  local script=$1 input=$2
  (cd "$repo" && printf '%s' "$input" | "$hooks/$script")
}

expect_json() {
  local name=$1 script=$2 filter=$3 input=$4 output
  tested+=("$script")
  output=$(run_hook "$script" "$input")
  printf '%s\n' "$output" | jq -e "$filter" >/dev/null
  printf 'ok %s\n' "$name"
}

expect_exit_2() {
  local name=$1 script=$2 input=$3 output status
  tested+=("$script")
  set +e
  output=$(run_hook "$script" "$input" 2>&1)
  status=$?
  set -e
  [ "$status" -eq 2 ]
  [ -n "$output" ]
  printf 'ok %s\n' "$name"
}

printf -v em_dash '\342\200\224'
printf 'tracked\n' >"$repo/tracked.txt"
git -C "$repo" init -q
git -C "$repo" add tracked.txt
git -C "$repo" -c user.name=test -c user.email=test@example.invalid commit -qm initial
printf 'flake\n' >"$repo/flake.nix"
printf 'module\n' >"$repo/untracked.nix"
printf '// one\n// two\n// three\n// four\n' >"$repo/comments.ts"
ln -s "$root/modules/eric/ai/pi/themes/catppuccin-mocha.json" "$repo/managed-link"

expect_json deny-symlink-path deny-symlink-path.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" '' "$repo/managed-link")"
expect_json block-smart-punct block-smart-punct.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" '' "$repo/new.txt" "em dash: $em_dash")"
expect_json block-git-config-edit-write block-git-config-edit.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" '' "$repo/.git/config")"
expect_json block-write-tracked block-write-tracked.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" '' "$repo/tracked.txt")"
expect_json git-add-before-nix git-add-before-nix.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'nix build')"
expect_json strip-claude-attribution strip-claude-attribution.sh '(.hookSpecificOutput.updatedInput.command | test("Co-Authored-By"; "i") | not)' \
  "$(json "$repo" "git commit -m 'x\nCo-Authored-By: Claude <noreply@anthropic.com>'")"
expect_json block-global-search block-global-search.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'find / -name nope')"
expect_json block-symlink-clobber block-symlink-clobber.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'echo x > managed-link')"
expect_json ask-dangerous-git ask-dangerous-git.sh '.hookSpecificOutput.permissionDecision == "ask"' \
  "$(json "$repo" 'git reset --hard')"
expect_json block-agent-commit block-agent-commit.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'git status --short
git commit --dry-run')"
git -C "$repo" config eric-agent.push ask
expect_json block-agent-push-ask block-agent-push.sh '.hookSpecificOutput.permissionDecision == "ask"' \
  "$(json "$repo" 'git push')"
git -C "$repo" config --unset eric-agent.push
expect_json block-agent-push-off block-agent-push.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'git push')"
git -C "$repo" config eric-agent.push on
tested+=(block-agent-push.sh)
output=$(run_hook block-agent-push.sh "$(json "$repo" 'git push')")
[ -z "$output" ]
printf 'ok block-agent-push-on\n'
expect_json block-git-config-edit-bash block-git-config-edit.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'echo x > .git/config')"
expect_json block-shell-edit block-shell-edit.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'sed -i s/tracked/changed/ tracked.txt')"
expect_json block-sudo-probe block-sudo-probe.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'sudo -n true')"
tested+=(treefmt-on-edit.sh)
run_hook treefmt-on-edit.sh "$(json "$repo" '' "$repo/tracked.txt")" >/dev/null
printf 'ok treefmt-on-edit\n'
expect_exit_2 warn-comment-block warn-comment-block.sh \
  "$(jq -cn --arg file_path "$repo/comments.ts" --arg text $'// one\n// two\n// three\n// four' '{tool_input:{file_path:$file_path,edits:[{new_string:$text}]}}')"

configured=$(jq -r '.hooks | to_entries[] | .value[] | .hooks[] | .command' "$settings" | sed -E 's#.*/##; s/"//g' | sort -u)
covered=$(printf '%s\n' "${tested[@]}" | sort -u)
[ "$configured" = "$covered" ] || {
  printf 'configured hook coverage mismatch\nexpected:\n%s\ncovered:\n%s\n' "$configured" "$covered" >&2
  exit 1
}
printf 'all configured hooks covered\n'

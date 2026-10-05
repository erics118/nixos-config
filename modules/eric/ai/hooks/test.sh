#!/usr/bin/env bash
set -euo pipefail

hooks=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$hooks/../../../../" && pwd)
settings="$root/modules/eric/ai/claude/settings.json"
repo=$(mktemp -d)
trap 'rm -rf "$repo"' EXIT

tested=()

json() {
  jq -cn --arg cwd "$1" --arg command "$2" --arg file_path "${3:-}" --arg content "${4:-}" --arg transcript_path "${5:-}" \
    '{cwd:$cwd,transcript_path:$transcript_path,tool_input:({command:$command} + if $file_path == "" then {} else {file_path:$file_path,content:$content} end)}'
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

expect_allow() {
  local name=$1 script=$2 input=$3 output
  tested+=("$script")
  output=$(run_hook "$script" "$input")
  [ -z "$output" ] || {
    printf 'FAIL %s: %s\n' "$name" "$output"
    exit 1
  }
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
# deny-symlink-path.sh only denies links that resolve under $HOME/nixos-config
# realpath because macOS temp dirs resolve through /private
fake_home=$(realpath "$repo")/home
mkdir -p "$fake_home/nixos-config"
printf 'managed\n' >"$fake_home/nixos-config/managed.txt"
ln -s "$fake_home/nixos-config/managed.txt" "$repo/managed-link"
# block-sudo-probe.sh only acts on macOS, so this shim keeps its cases live on linux
mkdir "$repo/bin"
printf '#!/bin/sh\necho Darwin\n' >"$repo/bin/uname"
chmod +x "$repo/bin/uname"

HOME=$fake_home expect_json deny-symlink-path deny-symlink-path.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" '' "$repo/managed-link")"
HOME=$fake_home expect_allow deny-symlink-path-regular deny-symlink-path.sh "$(json "$repo" '' "$repo/tracked.txt")"
expect_json block-smart-punct block-smart-punct.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" '' "$repo/new.txt" "em dash: $em_dash")"
expect_allow block-smart-punct-ascii block-smart-punct.sh "$(json "$repo" '' "$repo/new.txt" 'dash: - quotes: "x"')"
expect_json block-git-config-edit-write block-git-config-edit.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" '' "$repo/.git/config")"
expect_allow block-git-config-edit-write-other block-git-config-edit.sh "$(json "$repo" '' "$repo/config")"
expect_json block-write-tracked block-write-tracked.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" '' "$repo/tracked.txt")"
expect_allow block-write-tracked-untracked block-write-tracked.sh "$(json "$repo" '' "$repo/untracked.nix")"
expect_allow block-write-tracked-new block-write-tracked.sh "$(json "$repo" '' "$repo/new.txt")"
expect_json git-add-before-nix git-add-before-nix.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'nix build')"
expect_allow git-add-before-nix-not-nix git-add-before-nix.sh "$(json "$repo" 'git status')"
for cmd in 'rg -n home-manager modules' 'ls ~/.local/state/home-manager /tmp'; do
  expect_allow "git-add-before-nix: $cmd" git-add-before-nix.sh "$(json "$repo" "$cmd")"
done
expect_json git-add-before-nix-sudo git-add-before-nix.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'sudo darwin-rebuild switch --flake .')"
mkdir "$repo/sub"
git -C "$repo/sub" init -q
printf 'flake\n' >"$repo/sub/flake.nix"
git -C "$repo/sub" add flake.nix
printf 'new\n' >"$repo/sub/new.lua"
expect_json git-add-before-nix-non-nix git-add-before-nix.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo/sub" 'darwin-rebuild switch --flake .')"
git -C "$repo/sub" add new.lua
expect_allow git-add-before-nix-all-added git-add-before-nix.sh "$(json "$repo/sub" 'nix build')"
expect_json strip-claude-attribution strip-claude-attribution.sh '(.hookSpecificOutput.updatedInput.command | test("Co-Authored-By"; "i") | not)' \
  "$(json "$repo" "git commit -m 'x\nCo-Authored-By: Claude <noreply@anthropic.com>'")"
expect_allow strip-claude-attribution-plain strip-claude-attribution.sh "$(json "$repo" "git commit -m 'x'")"
expect_json block-global-search block-global-search.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'find / -name nope')"
expect_json block-global-search-unguarded-cd block-global-search.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'd=$(fd -t d gitsigns . | head -1); cd $d && rg -l GitSignsUpdate .')"
expect_json block-global-search-default-cd block-global-search.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'cd ${d:-}
rg x .')"
for cmd in 'cd "${d:?}" && rg -l GitSignsUpdate .' 'cd "$d" && rg x .' 'cd $dir/sub && rg x .' 'cd $d && ls' 'echo "cd $d && rg x ."'; do
  output=$(run_hook block-global-search.sh "$(json "$repo" "$cmd")")
  [ -z "$output" ] || {
    printf 'FAIL block-global-search allows: %s\n' "$cmd"
    exit 1
  }
done
printf 'ok block-global-search-guarded-cd\n'
for cmd in 'rg foo .' 'fd x .' 'find . -name x' "rg foo $repo"; do
  expect_allow "block-global-search: $cmd" block-global-search.sh "$(json "$repo" "$cmd")"
done
expect_json block-symlink-clobber block-symlink-clobber.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'echo x > managed-link')"
for cmd in 'mv /tmp/x managed-link && echo ok' 'cp /tmp/x managed-link; ls' 'cp /tmp/x managed-link 2>/dev/null' \
  'printf x | tee managed-link >/dev/null' 'cp a b; cp /tmp/x managed-link'; do
  expect_json "block-symlink-clobber: $cmd" block-symlink-clobber.sh '.hookSpecificOutput.permissionDecision == "deny"' \
    "$(json "$repo" "$cmd")"
done
expect_allow block-symlink-clobber-regular block-symlink-clobber.sh "$(json "$repo" 'cp /tmp/x other 2>/dev/null')"
expect_json ask-dangerous-git ask-dangerous-git.sh '.hookSpecificOutput.permissionDecision == "ask"' \
  "$(json "$repo" 'git reset --hard')"
for cmd in 'direnv exec . git reset --hard' 'bash -c "git reset --hard"' 'git clean -x -f' 'git stash drop' 'git stash clear' \
  'git checkout -f main' 'git switch --discard-changes main' 'git worktree remove --force x' \
  'git clean --force' 'git clean -d --force' 'bash -c "echo \"a b\" && git reset --hard"' \
  'git checkout -- f' 'git checkout feature -- src' 'git restore f' 'git restore -W f' 'git restore -S -W .' \
  'git restore --source=HEAD f' 'git switch -C main' 'git checkout -B main'; do
  expect_json "ask-dangerous-git: $cmd" ask-dangerous-git.sh '.hookSpecificOutput.permissionDecision == "ask"' \
    "$(json "$repo" "$cmd")"
done
for cmd in 'git stash list' 'git clean -n' 'git checkout main' 'git switch -c feat' 'git worktree remove x' \
  'git restore --staged f' 'git restore -S f'; do
  output=$(run_hook ask-dangerous-git.sh "$(json "$repo" "$cmd")")
  [ -z "$output" ] || {
    printf 'FAIL ask-dangerous-git asks: %s\n' "$cmd"
    exit 1
  }
done
printf 'ok ask-dangerous-git-safe\n'
expect_json block-agent-commit block-agent-commit.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'git status --short
git commit --dry-run')"
for cmd in 'direnv exec . git commit -m x' 'bash -c "git commit -m x"' "git -c 'alias.c=commit -m x' c"; do
  expect_json "block-agent-commit: $cmd" block-agent-commit.sh '.hookSpecificOutput.permissionDecision == "deny"' \
    "$(json "$repo" "$cmd")"
done
expect_json block-agent-commit-config-write block-agent-commit.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'git config eric-agent.commit on')"
expect_allow block-agent-commit-config-read block-agent-commit.sh "$(json "$repo" 'git config --get eric-agent.commit')"
git -C "$repo" config eric-agent.commit on
expect_allow block-agent-commit-on block-agent-commit.sh "$(json "$repo" 'git commit -m x')"
git -C "$repo" config eric-agent.commit branch
git -C "$repo" checkout -q -b feat
expect_allow block-agent-commit-branch-feature block-agent-commit.sh "$(json "$repo" 'git commit -m x')"
git -C "$repo" checkout -q -
expect_json block-agent-commit-branch-default block-agent-commit.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'git commit -m x')"
git -C "$repo" config eric-agent.commit ask
expect_json block-agent-commit-ask block-agent-commit.sh '.hookSpecificOutput.permissionDecision == "ask"' \
  "$(json "$repo" 'git commit -m x')"
expect_json block-agent-commit-ask-codex block-agent-commit.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'git commit -m x' '' '' "$HOME/.codex/sessions/rollout.jsonl")"
expect_json block-agent-commit-ask-codex-turn block-agent-commit.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(jq -cn --arg cwd "$repo" '{cwd:$cwd,transcript_path:null,turn_id:"t",tool_input:{command:"git commit -m x"}}')"
git -C "$repo" config --unset eric-agent.commit
git -C "$repo" config eric-agent.push ask
expect_json block-agent-push-ask block-agent-push.sh '.hookSpecificOutput.permissionDecision == "ask"' \
  "$(json "$repo" 'git push')"
expect_json block-agent-push-ask-codex block-agent-push.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'git push' '' '' "$HOME/.codex/sessions/rollout.jsonl")"
expect_json block-agent-push-ask-codex-turn block-agent-push.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(jq -cn --arg cwd "$repo" '{cwd:$cwd,transcript_path:null,turn_id:"t",tool_input:{command:"git push"}}')"
git -C "$repo" config --unset eric-agent.push
expect_json block-agent-push-off block-agent-push.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'git push')"
for cmd in 'direnv exec . git push' 'nix develop -c git push' 'xargs git push' 'find . -exec git push \;' 'timeout 10 git push' \
  'bash -c "git push origin main"' 'direnv exec . gh pr create' 'bash -c "gh pr create"' \
  "bash -l -c 'git push'" "bash -ec 'git push'" "sh -xc 'git push'" 'bash -c "echo \"a\"; git push"' \
  'env -i git push' 'command -p git push' 'sudo git push' 'nice git push' 'nohup git push' 'time git push' \
  'eval git push' 'git -P push' "git -c 'alias.p=!git push' p" 'git -c alias.p=push p'; do
  expect_json "block-agent-push: $cmd" block-agent-push.sh '.hookSpecificOutput.permissionDecision == "deny"' \
    "$(json "$repo" "$cmd")"
done
for cmd in 'direnv exec . git status' 'nix develop -c git status' 'bash -c "echo hi"' "bash -c 'echo hi'" 'echo "git push"' \
  "rg -n \"bash -c 'git push'\" docs"; do
  output=$(run_hook block-agent-push.sh "$(json "$repo" "$cmd")")
  [ -z "$output" ] || {
    printf 'FAIL block-agent-push denies: %s\n' "$cmd"
    exit 1
  }
done
printf 'ok block-agent-push-safe\n'
git -C "$repo" config eric-agent.push on
tested+=(block-agent-push.sh)
output=$(run_hook block-agent-push.sh "$(json "$repo" 'git push')")
[ -z "$output" ]
printf 'ok block-agent-push-on\n'
for cmd in 'gh pr view 1' 'gh pr list' 'gh pr diff 1' 'gh run view 1' 'gh api repos/o/r/pulls' 'gh search code x'; do
  expect_allow "block-agent-push: $cmd" block-agent-push.sh "$(json "$repo" "$cmd")"
done
for cmd in 'gh pr merge 1' 'gh api -X DELETE repos/o/r' 'gh api repos/o/r/issues -f title=x' 'gh auth status --show-token' \
  'gh api repos/o/r/issues -ftitle=x' 'gh api repos/o/r/issues -Ftitle=x'; do
  expect_json "block-agent-push: $cmd" block-agent-push.sh '.hookSpecificOutput.permissionDecision == "deny"' \
    "$(json "$repo" "$cmd")"
done
expect_json block-git-config-edit-bash block-git-config-edit.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'echo x > .git/config')"
expect_json block-shell-edit block-shell-edit.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'sed -i s/tracked/changed/ tracked.txt')"
for cmd in 'echo x > tracked.txt' 'printf x | tee -a tracked.txt' "python3 -c \"open('tracked.txt', 'w').write('x')\""; do
  expect_json "block-shell-edit: $cmd" block-shell-edit.sh '.hookSpecificOutput.permissionDecision == "deny"' \
    "$(json "$repo" "$cmd")"
done
for cmd in 'sed -n p tracked.txt' 'sed -i s/a/b/ untracked.nix' 'echo x > new.txt' 'cat tracked.txt > /dev/null'; do
  expect_allow "block-shell-edit: $cmd" block-shell-edit.sh "$(json "$repo" "$cmd")"
done
PATH="$repo/bin:$PATH" expect_json block-sudo-probe block-sudo-probe.sh '.hookSpecificOutput.permissionDecision == "deny"' \
  "$(json "$repo" 'sudo -n true')"
PATH="$repo/bin:$PATH" expect_allow block-sudo-probe-plain block-sudo-probe.sh "$(json "$repo" 'sudo true')"
expect_allow treefmt-on-edit-no-envrc treefmt-on-edit.sh "$(json "$repo" '' "$repo/tracked.txt")"
if command -v direnv >/dev/null 2>&1; then
  # a stub treefmt that rewrites the file and fails shows the hook ran it and still exits silently
  # direnv exec does not match an allow made through a symlinked path like /tmp
  fmt=$(realpath "$repo")/fmt
  mkdir -p "$fmt/bin"
  printf 'PATH_add bin\n' >"$fmt/.envrc"
  printf '#!/bin/sh\nprintf "formatted\\n" >"$1"\nexit 1\n' >"$fmt/bin/treefmt"
  chmod +x "$fmt/bin/treefmt"
  printf 'raw\n' >"$fmt/file.txt"
  # a private direnv allow list and config keep the user's direnv state out of the test
  XDG_DATA_HOME=$repo/xdg XDG_CONFIG_HOME=$repo/xdg direnv allow "$fmt" 2>/dev/null
  XDG_DATA_HOME=$repo/xdg XDG_CONFIG_HOME=$repo/xdg expect_allow treefmt-on-edit-formats treefmt-on-edit.sh \
    "$(json "$repo" '' "$fmt/file.txt")"
  [ "$(cat "$fmt/file.txt")" = formatted ] || {
    printf 'FAIL treefmt-on-edit did not run treefmt\n'
    exit 1
  }
else
  printf 'skip treefmt-on-edit-formats: direnv is not on PATH\n'
fi
expect_exit_2 warn-comment-block warn-comment-block.sh \
  "$(jq -cn --arg file_path "$repo/comments.ts" --arg text $'// one\n// two\n// three\n// four' '{tool_input:{file_path:$file_path,edits:[{new_string:$text}]}}')"
expect_allow warn-comment-block-short warn-comment-block.sh \
  "$(jq -cn --arg file_path "$repo/comments.ts" --arg text $'// one\n// two\ncode' '{tool_input:{file_path:$file_path,edits:[{new_string:$text}]}}')"

configured=$(jq -r '.hooks | to_entries[] | .value[] | .hooks[] | .command' "$settings" | sed -E 's#.*/##; s/"//g' | sort -u)
covered=$(printf '%s\n' "${tested[@]}" | sort -u)
[ "$configured" = "$covered" ] || {
  printf 'configured hook coverage mismatch\nexpected:\n%s\ncovered:\n%s\n' "$configured" "$covered" >&2
  exit 1
}
printf 'all configured hooks covered\n'

codex_configured=$(jq -r '.hooks | to_entries[] | .value[] | .hooks[] | .command' "$root/modules/eric/ai/codex/hooks.json" | sed -E 's#.*/##; s/"//g' | sort -u)
for script in $codex_configured; do
  if [ ! -x "$hooks/$script" ] || ! printf '%s\n' "$covered" | grep -qxF "$script"; then
    printf 'codex hook %s is missing or untested\n' "$script" >&2
    exit 1
  fi
done
printf 'all codex hooks covered\n'

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
  expect_rule prompt git checkout -- .
  expect_rule prompt git restore -- .
  expect_rule prompt git reset --hard
  expect_rule allow git status
  expect_rule allow rg foo .
  expect_rule none git checkout main
  expect_rule prompt git checkout -- f
  expect_rule prompt git restore f
  expect_rule prompt git restore --staged f
else
  printf 'skip codex-rules: codex is not on PATH\n'
fi

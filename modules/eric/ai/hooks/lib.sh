#!/usr/bin/env bash
# shellcheck disable=SC2016
# shared helpers for PreToolUse/PostToolUse hooks. source, don't run directly:
#   source "$(dirname "$0")/lib.sh"

# fail closed when a dependency is missing. these guards are the only gate under
# defaultMode auto, so a hook that cannot run must block rather than silently allow.
# exit 2 blocks the call and feeds stderr back, which works without jq.
hook_require() {
  for b in "$@"; do
    command -v "$b" >/dev/null 2>&1 && continue
    printf 'guard hook cannot run: %s is not on PATH, so the command was not checked.\n' "$b" >&2
    exit 2
  done
}

# any other failure blocks too, since claude code and codex run the command on every exit code but 2
trap 'rc=$?; [ "$rc" -eq 0 ] || [ "$rc" -eq 2 ] || { printf "guard hook failed with exit %s, so the command was not checked.\n" "$rc" >&2; exit 2; }' EXIT

# reads stdin once. sets $HOOK_INPUT (raw json) and $HOOK_COMMAND (tool_input.command).
# exits 0 (no-op) if there's no command to inspect.
hook_read_command() {
  HOOK_INPUT=$(cat)
  HOOK_COMMAND=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
  [ -n "$HOOK_COMMAND" ] || exit 0
}

# same, for Write/Edit's tool_input.file_path. sets $HOOK_INPUT and $HOOK_FILE.
hook_read_file_path() {
  HOOK_INPUT=$(cat)
  HOOK_FILE=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
  [ -n "$HOOK_FILE" ] || exit 0
}

# directory a command runs in: the hook's cwd, or the target when the command starts with `cd DIR`.
# sets $HOOK_DIR (requires hook_parse_command to have run first).
hook_command_dir() {
  HOOK_DIR=$(printf '%s' "$HOOK_INPUT" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$HOOK_DIR" ] || HOOK_DIR=$PWD
  local to
  to=$(printf '%s' "$HOOK_CALLS" | jq -s -r '.[0] // {} | select(.argv[0] == "cd" and (.argv | length) == 2) | .argv[1]')
  [ -z "$to" ] || HOOK_DIR=$(hook_resolve "$to")
}

# a path with a leading ~ expanded and a relative path joined onto $HOOK_DIR. empty means $HOOK_DIR
hook_resolve() {
  local p=${1/#\~/$HOME}
  case "$p" in '') p=$HOOK_DIR ;; /*) ;; *) p=$HOOK_DIR/$p ;; esac
  printf '%s' "$p"
}

# true when the hook runs under codex, which runs a hook's ask as allow
hook_is_codex() {
  printf '%s' "$HOOK_INPUT" | jq -e 'has("turn_id") or (.transcript_path // "" | contains("/.codex/"))' >/dev/null
}

# set $HOOK_CALLS to one {argv, dyn, redirs} json line per simple command, wrapped commands also unwrapped
# a command as written behind env, sudo, xargs, and the like has wrapper: true. dyn marks a bare unquoted $var or $(...), and `sh -c` and `eval` scripts are parsed too
# a command shfmt cannot parse is denied (requires hook_read_command)
hook_parse_command() {
  HOOK_CALLS=$(hook_calls_of "$HOOK_COMMAND" 0) ||
    hook_deny "The guard hooks could not parse this command, so they could not check it: $HOOK_CALLS. Rewrite it in plain bash syntax."
}

hook_calls_of() {
  local ast calls script sub
  ast=$(printf '%s' "$1" | shfmt -ln zsh --to-json 2>&1) || {
    printf '%s' "$ast"
    [ "$2" -eq 0 ] || printf ' in the nested script: %s' "$1"
    return 1
  }
  calls=$(printf '%s' "$ast" | jq -c "$HOOK_CALLS_JQ") || return 1
  # on failure print only the error, so nested calls are gathered first
  if [ "$2" -lt 3 ]; then
    # scripts stay json-encoded until here, so one with a newline is one line
    while IFS= read -r script; do
      script=$(printf '%s' "$script" | jq -r .)
      sub=$(hook_calls_of "$script" $(($2 + 1))) || {
        printf '%s' "$sub"
        return 1
      }
      [ -z "$sub" ] || calls+=${calls:+$'\n'}$sub
    done < <(printf '%s' "$calls" | jq -c '.script // empty')
  fi
  [ -z "$calls" ] || printf '%s\n' "$calls"
}

HOOK_CALLS_JQ='
  def part: if .Type == "Lit" then .Value | gsub("\\\\(?<c>.)"; .c)
    elif .Type == "SglQuoted" then .Value
    elif .Type == "DblQuoted" then [.Parts[]? | part] | join("")
    elif .Type == "ParamExp" then "$" + (.Param.Value // "")
    else "$(...)" end;
  def word: [.Parts[]? | part] | join("");
  # ${d:?} fails when empty, so only other bare expansions can expand to nothing
  def dyn: (.Parts | length) == 1 and (.Parts[0] |
    (.Type == "ParamExp" and ((.Exp.Op // "") | test("\\?") | not)) or .Type == "CmdSubst");
  # index of the first word after a wrapper and its options. $vals lists the options that take a value
  def opts($vals): . as $a | def go($i):
      if $i >= ($a | length) then $i
      elif $a[$i] == "--" then $i + 1
      elif ($a[$i] | test("^-|^[A-Za-z_][A-Za-z0-9_]*=")) then
        (if ($vals | index([$a[$i]])) then go($i + 2) else go($i + 1) end)
      else $i end;
    go(1);
  def pos($xs): . as $a | ([range(length) | select($a[.] as $w | $xs | index([$w]))][0] // null) | if . then . + 1 else 0 end;
  # how many leading words are wrappers around the real command
  def off: if length == 0 then 0 else
      (.[0] | sub(".*/"; "")) as $c |
      (if $c == "env" then opts(["-u", "-C", "-S"])
       elif ["command", "builtin", "exec", "nohup", "eval", "time"] | index([$c]) then opts([])
       elif $c == "sudo" then opts(["-u", "-g", "-p", "-C", "-D", "-h", "-R", "-T", "-U"])
       elif $c == "nice" then opts(["-n"])
       elif $c == "timeout" or $c == "gtimeout" then opts(["-s", "-k"]) + 1
       elif $c == "xargs" then opts(["-I", "-n", "-P", "-L", "-d", "-E", "-s", "-a"])
       elif $c == "direnv" and .[1] == "exec" then 3
       elif $c == "nix" and (.[1] == "develop" or .[1] == "shell") then pos(["-c", "--command"])
       elif $c == "find" then pos(["-exec", "-execdir", "-ok", "-okdir"])
       else 0 end) as $n |
      if $n > 0 and $n < length then $n + (.[$n:] | off) else 0 end
    end;
  # the script a shell runs with -c, or the words eval joins
  def script: (.[0] // "" | sub(".*/"; "")) as $c |
    if $c == "eval" then .[1:] | join(" ")
    elif ["sh", "bash", "zsh", "dash"] | index([$c]) then
      . as $a | ([range(1; length) | select($a[.] | test("^-[A-Za-z]*c[A-Za-z]*$"))][0]) as $i |
      if $i then $a[$i + 1] else null end
    else null end;
  .. | objects | select(has("Cmd") and (.Cmd == null or .Cmd.Type == "CallExpr")) |
    {argv: [.Cmd.Args[]? | word], dyn: [.Cmd.Args[]? | dyn], redirs: [.Redirs[]? | {op: .Op, fd: (.N.Value // ""), word: (.Word | word)}]} |
    (.argv | off) as $n |
    (if $n > 0 then .wrapper = true else . end), (select($n > 0) | .prefix = .argv[:$n] | .argv |= .[$n:] | .dyn |= .[$n:]) |
    (.argv | script) as $s | if $s then .script = $s else . end
'

# jq helpers over one $HOOK_CALLS line. git yields the subcommand and its words after global options
HOOK_JQ='
  def tool: .argv[0] // "" | sub(".*/"; "");
  def git: select(tool == "git") | .argv[1:] |
    until(length == 0 or (.[0] | startswith("-") | not);
      if .[0] | IN("-C", "-c", "--git-dir", "--work-tree", "--namespace", "--config-env") then .[2:] else .[1:] end) |
    select(length > 0);
  # files a > or >> redirect or tee writes
  def writes: (.redirs[] | select(.op | IN(">", ">>", ">|", "&>", "&>>")) | .word),
    (select(tool == "tee") | .argv[1:][] | select(startswith("-") | not));
  # the words from each global option on, since commit -C names a commit
  def git_opts: .argv[1:] | recurse(if length > 0 and (.[0] | startswith("-")) then
      (if .[0] | IN("-C", "-c", "--git-dir", "--work-tree", "--namespace", "--config-env") then .[2:] else .[1:] end) else empty end) |
    select(length > 0 and (.[0] | startswith("-")));
  def git_dir: [git_opts | select(.[0] == "-C") | .[1] // empty][0] // "";
  # an alias, or an include that can define one, set with -c or --config-env
  def git_alias: tool == "git" and (.argv as $a | any(range(1; $a | length);
    (($a[.] | IN("-c", "--config-env")) and ($a[. + 1] // "" | ascii_downcase | test("^(alias|include|includeif)\\."))) or
    ($a[.] | ascii_downcase | test("^(-c|--config-env=)(alias|include|includeif)\\."))));
  # a repo named some way other than one -C, which git_dir cannot see.
  # a wrapper can change directory too, with env -C or --chdir, sudo -D, or find -execdir
  def git_elsewhere: tool == "git" and (([git_opts | select(.[0] == "-C")] | length > 1) or
    any(git_opts; .[0] | test("^--(git-dir|work-tree)(=|$)")) or
    any(git_opts; ((.[0] | IN("-c", "--config-env")) and (.[1] // "" | ascii_downcase | startswith("core.worktree"))) or
      (.[0] | ascii_downcase | test("^(-c|--config-env=)core\\.worktree"))) or
    any(.prefix[]?; test("^(-C|-D|--chdir|-execdir|-okdir)")));
  # over git output: a --dry-run, or push -n, that git reads as an option.
  # after -- it is a path, and after an option that takes a value it is that value, such as a -m message
  def git_dry_run: . as $a | ($a | index(["--"]) // length) as $end | any(range(1; $end);
    ($a[.] == "--dry-run" or ($a[0] == "push" and $a[.] == "-n")) and
    ($a[. - 1] | IN("-m", "-F", "-C", "-c", "-t", "-o", "--message", "--file", "--reuse-message", "--reedit-message", "--author",
      "--date", "--template", "--cleanup", "--fixup", "--squash", "--trailer", "--push-option", "--repo", "--receive-pack", "--exec") | not));
'

# true when any $HOOK_CALLS line meets the jq condition, which can use the $HOOK_JQ helpers
# a jq error exits rather than reading as false
hook_any() {
  local rc=0
  printf '%s' "$HOOK_CALLS" | jq -s -e "$HOOK_JQ any(.[]; $1)" >/dev/null || rc=$?
  [ "$rc" -le 1 ] || exit "$rc"
  return "$rc"
}

# deny a GIT_DIR, GIT_WORK_TREE, or GIT_CONFIG* assignment, which moves git to a repo or config the gates do not read
hook_deny_git_env() {
  [[ $HOOK_COMMAND =~ (^|[^A-Za-z0-9_])GIT_(CONFIG[A-Z0-9_]*|DIR|WORK_TREE)= ]] &&
    hook_deny 'Agents never set GIT_DIR, GIT_WORK_TREE, or GIT_CONFIG* variables. Name the repo with git -C.'
  return 0
}

# set $HOOK_GATE_DIRS to the repos, one per line, where a call meeting the jq filter runs
# deny when a later cd or --git-dir could move such a call into a repo the gate does not read
hook_gate_dirs() {
  HOOK_GATE_DIRS=
  hook_any "$1" || return 0
  # hook_command_dir follows only a leading `cd DIR`
  printf '%s' "$HOOK_CALLS" | jq -s -e '(.[1:] | any(.argv[0] // "" | IN("cd", "pushd"))) or
    (.[0].argv // [] | .[0] == "pushd" or (.[0] == "cd" and length != 2))' >/dev/null &&
    hook_deny 'A git commit or push here follows a cd other than a leading `cd DIR`. Put a plain cd first, or name the repo with git -C.'
  hook_any "($1) and git_elsewhere" &&
    hook_deny 'A git commit or push here names its repo with --git-dir, --work-tree, core.worktree, a second -C, or a wrapper that changes directory. Name the repo with one git -C.'
  # shellcheck disable=SC2034
  HOOK_GATE_DIRS=$(hook_each "select($1) | git_dir" | while IFS= read -r d; do printf '%s\n' "$(hook_resolve "$d")"; done | sort -u)
}

# print the jq filter's raw output for each $HOOK_CALLS line, with the $HOOK_JQ helpers available
hook_each() {
  printf '%s' "$HOOK_CALLS" | jq -r "$HOOK_JQ $1"
}

# true when the path, relative to $HOOK_DIR, is an existing file that git tracks.
hook_tracked() {
  local f
  f=$(hook_resolve "$1")
  [ -f "$f" ] && git -C "$(dirname "$f")" ls-files --error-unmatch -- "$(basename "$f")" >/dev/null 2>&1
}

# print a PreToolUse deny decision with the given reason, then exit.
hook_deny() {
  jq -cn --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"deny", permissionDecisionReason:$reason}}'
  exit 0
}

# print a PreToolUse ask decision with the given reason, then exit. forces the normal
# permission prompt instead of refusing outright.
hook_ask() {
  jq -cn --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"ask", permissionDecisionReason:$reason}}'
  exit 0
}

# print an updated tool_input.command (requires hook_read_command to have run first), then exit.
hook_update_command() {
  printf '%s' "$HOOK_INPUT" | jq -c --arg cmd "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse", updatedInput:(.tool_input | .command=$cmd)}}'
  exit 0
}

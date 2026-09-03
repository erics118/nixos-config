#!/usr/bin/env bash
# flag comment blocks longer than 3 lines in the written file, new or pre-existing.
# the rule lives in CLAUDE.md but prose does not fire at edit time; this does.
set -u
source "$HOME/.claude/hooks/lib.sh"

hook_require jq
HOOK_INPUT=$(cat)

file=$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty')
[ -n "$file" ] || exit 0
[ -f "$file" ] || exit 0

case "$file" in
*.c | *.cc | *.cpp | *.cxx | *.h | *.hpp | *.hh | *.js | *.jsx | *.ts | *.tsx | *.go | *.rs | *.java | *.kt | *.swift | *.cs | *.scala | *.php | *.json | *.jsonc | *.json5) mode=slash ;;
*.css | *.scss | *.less) mode=block ;;
*.sh | *.bash | *.zsh | *.py | *.nix | *.yaml | *.yml | *.toml | *.rb | *.pl) mode=hash ;;
*) exit 0 ;;
esac

read -r max at < <(awk -v mode="$mode" '
{
  line=$0; c=0
  if(mode=="hash"){
    if(line ~ /^[[:space:]]*#!/) c=0
    else if(line ~ /^[[:space:]]*#/) c=1
  } else {
    if(inblock){ c=1; if(line ~ /\*\//) inblock=0 }
    else if(mode=="slash" && line ~ /^[[:space:]]*\/\//) c=1
    else if(line ~ /^[[:space:]]*\/\*/){ c=1; if(line !~ /\*\//) inblock=1 }
  }
  if(c){ run++; if(run>max){max=run; at=NR} } else run=0
}
END{ print max+0, at+0 }' "$file")

[ "${max:-0}" -ge 4 ] || exit 0

printf 'comment block of %s lines ending at %s:%s. CLAUDE.md: one line is best, two or three max, never a rationale/essay block. cut it to the durable fact or delete it.\n' "$max" "$file" "$at" >&2
exit 2

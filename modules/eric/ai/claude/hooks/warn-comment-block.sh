#!/usr/bin/env bash
# flag comment blocks longer than 3 lines in the text an edit introduced.
# the rule lives in CLAUDE.md but prose does not fire at edit time; this does.
# scans only newly written text so pre-existing blocks in an edited file stay quiet.
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

# only the text this tool call wrote: Write content, Edit new_string, MultiEdit each new_string
added=$(printf '%s' "$HOOK_INPUT" | jq -r '
  if .tool_input.content != null then .tool_input.content
  elif .tool_input.new_string != null then .tool_input.new_string
  elif .tool_input.edits != null then [.tool_input.edits[].new_string] | join("\n")
  else empty end')
[ -n "$added" ] || exit 0

out=$(printf '%s\n' "$added" | awk -v mode="$mode" '
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
  if(c){ run++; if(run>max){max=run; endline=line} } else run=0
}
END{ print max+0; print endline }')
max=$(printf '%s\n' "$out" | sed -n '1p')
endc=$(printf '%s\n' "$out" | sed -n '2p')

[ "${max:-0}" -ge 4 ] || exit 0

# locate the added block in the file for a real line number, else name the file alone
at=$(grep -nF -- "$endc" "$file" 2>/dev/null | head -1 | cut -d: -f1)
loc="$file"
[ -n "$at" ] && loc="$file:$at"

printf 'comment block of %s lines ending at %s. CLAUDE.md: one line is best, two or three max, never a rationale/essay block. cut it to the durable fact or delete it.\n' "$max" "$loc" >&2
exit 2

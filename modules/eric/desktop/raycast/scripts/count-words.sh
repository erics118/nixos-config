#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Count Words
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🤖
# @raycast.argument1 { "type": "text", "placeholder": "Text", "optional": true }
# @raycast.packageName Developer Utilities

# Documentation:
# @raycast.description Counts the words of either the clipboard or the passed argument
# @raycast.author erics118
# @raycast.authorURL https://github.com/erics118

arg=$1

# no argument, so use the clipboard
if [ -z "$arg" ]; then
  arg=$(pbpaste)
fi

n=$(printf '%s' "$arg" | wc -w | xargs)

s=s
[ "$n" -eq 1 ] && s=
echo "$n word$s"

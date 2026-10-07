#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Sort Lines
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🤖
# @raycast.packageName Developer Utilities

# Documentation:
# @raycast.description Sorts the lines of the clipboard in place
# @raycast.author erics118
# @raycast.authorURL https://github.com/erics118

pbpaste | sort | pbcopy

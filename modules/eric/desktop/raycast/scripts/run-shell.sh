#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Run Shell Script
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon images/shell.png
# @raycast.argument1 { "type": "text", "placeholder": "Command" }
# @raycast.packageName Developer Utilities

# Documentation:
# @raycast.description Runs a shell command from the home directory
# @raycast.author erics118
# @raycast.authorURL https://github.com/erics118

cd ~ || exit

eval "$*"

#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Generate Password
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🔑
# @raycast.packageName Developer Utilities

# Documentation:
# @raycast.description Generates a password and copies it to the clipboard
# @raycast.author erics118
# @raycast.authorURL https://github.com/erics118

password=$(/etc/profiles/per-user/eric/bin/generate-password)

printf '%s' "$password" | /etc/profiles/per-user/eric/bin/pbcopy-secret

echo "Copied $password"

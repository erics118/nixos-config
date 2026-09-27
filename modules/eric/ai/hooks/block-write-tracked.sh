#!/usr/bin/env bash
# block Write over an existing git-tracked file. a whole-file write hides what changed,
# so edits to tracked files go through Edit, which shows a diff
set -u
source "$(dirname "$0")/lib.sh"

hook_require jq git
hook_read_file_path

[ -f "$HOOK_FILE" ] || exit 0
git -C "$(dirname "$HOOK_FILE")" ls-files --error-unmatch -- "$(basename "$HOOK_FILE")" >/dev/null 2>&1 || exit 0
hook_deny "$HOOK_FILE is tracked by git. Change it with Edit so the change shows as a reviewable diff. Write is for new files."

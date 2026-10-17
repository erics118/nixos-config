# shellcheck shell=bash disable=SC2154
# block Write over an existing git-tracked file
# a whole-file write regenerates every line and can silently change lines outside the request
# Edit touches only the matched text

hook_read_file_path

[ -f "$HOOK_FILE" ] || exit 0
git -C "$(dirname "$HOOK_FILE")" ls-files --error-unmatch -- "$(basename "$HOOK_FILE")" >/dev/null 2>&1 || exit 0
hook_deny "$HOOK_FILE is tracked by git. Use Edit so lines outside the change stay untouched. Write is for new files."

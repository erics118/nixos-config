#!/usr/bin/env bash
# block Bash writes onto a path that is currently a symlink
# mv and in-place sed/perl replace the link, detaching nix-managed config from its source
# cp, tee, truncate, and redirects write through the link, outside the edit tool
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
source "$(dirname "$0")/lib.sh"

hook_require jq realpath shfmt
hook_read_command
hook_parse_command

# every path this command would overwrite: the destination of mv/cp, the files tee writes,
# the file of an in-place editor (sed -i, perl -i, truncate), and each > or >> target
while IFS= read -r candidate; do
  # fd dupes like 2>&1 and device sinks are not files we can clobber
  case "$candidate" in '&'* | /dev/*) continue ;; esac
  # expand a literal leading ~ or $HOME without eval (never execute embedded command substitutions)
  candidate="${candidate/#\~/$HOME}"
  candidate="${candidate//\$HOME/$HOME}"
  [ -L "$candidate" ] || continue

  real=$(realpath "$candidate" 2>/dev/null)
  hook_deny "$candidate is a symlink (-> $real). mv or in-place sed/perl would replace the link itself, and cp, tee, truncate, or a redirect would write through it. Edit $real directly instead."
done < <(hook_each '
  writes,
  (select(tool | IN("mv", "cp")) | .argv[1:] | select(length > 1) | .[-1]),
  (select((tool | IN("sed", "perl")) and any(.argv[1:][]; test("^-[a-zA-Z]*i|^--in-place"))) | .argv[-1]),
  (select(tool == "truncate") | .argv[-1])
')

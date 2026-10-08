#!/usr/bin/env bash
# shellcheck disable=SC2016
# block `find`, `fd`, `rg`, and `grep` commands rooted at / (or other filesystem-wide roots): scanning the
# whole filesystem is slow, can hang on network/special mounts, and is never what's needed.
# also block a search after a cd that can land in $HOME
set -u
# shellcheck source-path=SCRIPTDIR source=lib.sh
source "$(dirname "$0")/lib.sh"

hook_require jq shfmt
hook_read_command
hook_parse_command

defs='
  def search: tool | IN("find", "fd", "rg", "grep");
  # a filesystem-wide root: / , /nix, /nix/store, /nix/var(/nix), whole $HOME / ~ / /home/<user>, or a huge/
  # hang-prone system root. bounded subpaths (. , /home/eric/dev , ~/proj, /nix/store/<hash>-name) pass
  def root: test("^(/|~/?|\\$HOME/?|/nix(/(store|var(/nix)?))?/?\\*?|/(home|Users)(/[^/]+)?/?|/(usr|var|proc|sys|System|Library|private|Volumes)/?)$");
  def leading: if length > 0 and (.[0] | test("^[-(!]") | not) then [.[0]] + (.[1:] | leading) else [] end;
'

# find takes its roots before the first expression word, after -H, -L, or -P.
# fd, rg, and grep take the pattern first and paths after it, unless --files or a path flag names them
hook_any "$defs"'
  def paths: .argv[1:] as $a |
    if tool == "find" then $a | until(length == 0 or (.[0] | test("^-[HLP]$") | not); .[1:]) | leading
    else ([$a[] | select(startswith("-") | not)] | if $a | index(["--files"]) then . else .[1:] end) +
      [range($a | length) as $i | $a[$i] |
        if test("^--(base-directory|search-path)=") then sub("^[^=]*="; "")
        elif IN("--base-directory", "--search-path") then $a[$i + 1] // empty
        else empty end]
    end;
  search and any(paths[]; root)
' &&
  hook_deny 'find, fd, rg, or grep rooted at a filesystem-wide directory (/, /nix, ~, $HOME, /home/<user>, /Users/<user>, or a system root) scans far too much and can hang on special mounts. Search from a specific directory instead (e.g. `fd <pattern> .` or `fd <pattern> /path/to/project`).'

# a bare `cd`, or an unquoted `cd $var` / `cd ${var:-}` / `cd $(...)` that is the whole
# argument, lands in $HOME when it expands to nothing, so a later relative search scans all of it
kinds=$(hook_each "$defs"'
  def to_home: tool == "cd" and ([range(1; .argv | length) as $i | select(.argv[$i] != "--") | .dyn[$i]] |
    length == 0 or (length == 1 and .[0]));
  if to_home then "cd" elif search then "search" else empty end
' | paste -sd ' ' -)
[[ $kinds == *cd*search* ]] &&
  hook_deny 'a search after a bare `cd` or an unquoted `cd $var` / `cd $(...)`: if the expansion is empty, cd goes to $HOME and the search scans all of it. Guard it: `cd -- "${var:?}"`.'

exit 0

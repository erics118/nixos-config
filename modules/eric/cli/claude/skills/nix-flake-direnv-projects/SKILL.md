---
name: nix-flake-direnv-projects
description: Use when working in one of the user's dev projects that has a flake.nix and a .envrc (direnv) - building, testing, running linters/formatters/tooling, or adding new files there.
---

# Nix flake + direnv projects

## Overview

Most of the user's projects (`~/dev/*`, `~/nixos-config`) get their dev environment from a `flake.nix` devShell, activated by direnv via a `.envrc`. Most toolchains (compilers, language servers, `dune`, `cargo`, etc.) live in that shell, not on the global PATH. Assume nothing language-specific is globally installed.

## Conventions

- `.envrc` is almost always just `use flake`. Sometimes there are extra `export`s for certain environment variable. Also, there might be `use nix -p <pkg>` for adding a package without needing a `flake.nix`
- You are already in the devshell, you invoke commands directly, not with `direnv exec`
- New nix files must be `git add`ed before any nix eval/build/check - flakes ignore untracked files. No commit needed. Never `git commit` unless asked.
- On macOS, we do not use homebrew/brew, and we still use nix for managing dependencies.

## Overrides win

Some projects do not use nix. Do not propose a flake/nix/direnv solution if it does not use nix.

## Repo-specific detail

`~/nixos-config` has its own CLAUDE.md with deeper conventions (symlink patterns, `just` recipes, platform checks). Read it when working there.

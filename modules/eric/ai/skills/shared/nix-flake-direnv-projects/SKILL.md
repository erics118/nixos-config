---
name: nix-flake-direnv-projects
description: Use when working in one of the user's dev projects that has a flake.nix and a .envrc (direnv) - building, testing, running linters/formatters/tooling, or adding new files there.
---

# Nix flake + direnv projects

Most of the user's projects (`~/dev/*`, `~/nixos-config`) get their dev environment from a `flake.nix` devShell, activated by direnv via a `.envrc`. Toolchains (compilers, language servers, `dune`, `cargo`) live in that shell, not on the global PATH. Assume nothing language-specific is globally installed.

- `.envrc` is almost always just `use flake`, sometimes with extra `export`s, sometimes `use nix -p <pkg>` to add a package without a `flake.nix`
- You are already in the devshell, so invoke commands directly rather than through `direnv exec`
- Match whatever the project already uses; some are not nix projects at all

`~/nixos-config` has its own CLAUDE.md with deeper conventions (symlink patterns, `just` recipes, platform checks). Read it when working there.

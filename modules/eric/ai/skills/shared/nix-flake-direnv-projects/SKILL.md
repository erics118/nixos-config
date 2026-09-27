---
name: nix-flake-direnv-projects
description: Use when working in one of the user's dev projects that has a flake.nix and a .envrc (direnv) - building, testing, running linters/formatters/tooling, adding new files there, or needing a CLI tool that isn't on PATH.
---

# Nix flake + direnv projects

Most of the user's projects (`~/dev/*`, `~/nixos-config`) get their dev environment from a `flake.nix` devShell, activated by direnv via a `.envrc`. Toolchains (compilers, language servers, `dune`, `cargo`) live in that shell, not on the global PATH. Assume nothing language-specific is globally installed.

- `.envrc` is almost always just `use flake`, sometimes with extra `export`s, sometimes `use nix -p <pkg>` to add a package without a `flake.nix`
- If the session started inside this project, the devshell is already loaded: invoke commands directly. For any other project, run `direnv exec <project-dir> <cmd>`
- Need a CLI tool that isn't in the devshell? For a one-off, run `nix shell nixpkgs#<pkg> --command <cmd>`. Add it to `flake.nix`'s devShell `packages` (search nixpkgs for the right attr name) only when the project needs it for good. Never fall back to brew, pip, or a system binary, and never report the task blocked
- Match whatever the project already uses; some are not nix projects at all

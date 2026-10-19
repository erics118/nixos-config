# nixos-config

- Managed files use `repoFile` or `repoFileAll` from `modules/features/base/flake-link.nix`. `repoFile path` is `mkOutOfStoreSymlink "~/.flake/<path>"`, and `~/.flake` is a symlink to `~/nixos-config`. So the chain is target -> `/nix/store/...-home-manager-files/<target>` -> `/nix/store/...-hm_<name>` -> `~/.flake/<path>` -> the repo file. `repoFileAll dir target` makes one such symlink per git-tracked file that existed in `dir` at eval time
- Files read with `builtins.readFile` or `source = ./...` are copied into the store, so editing them needs `just switch`
- A module that takes no arguments is a plain attrset, not a function that ignores them (`_: { ... }`)
- import-tree loads every `.nix` file under `modules/` as a flake module, except paths with a `/_` segment. A plain nix expression there, such as a `callPackage` file, breaks evaluation
- The agent guard hooks are the Go program in `modules/eric/ai/guard/`, packaged by `modules/overlays/agent-guard.nix`. A change there goes live only with `just switch`. `bash modules/eric/ai/hooks/test.sh`, with `go` from the devShell, tests the working tree's copy. `modules/eric/ai/README.md` lists the checks
- Check the platform with `pkgs.stdenv.hostPlatform.isDarwin` or `.isLinux`, never by matching the `system` string
- Prefer a declarative nix-darwin or home-manager module (a launchd agent, a nix package) over imperative setup or a hand-cloned repo
- When a nix-managed symlink replaces an existing config dir, move the old one to `<dir>.bak`, never delete it. Only the user removes the `.bak`
- Scripts that run only on the user's machines can use zsh-isms. Keep POSIX `sh` for CI, containers, and anything distributed

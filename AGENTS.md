# nixos-config

- Managed files use `repoFile` or `repoFileAll` from `modules/features/base/flake-link.nix`. `repoFile path` is `mkOutOfStoreSymlink "~/.flake/<path>"`, and `~/.flake` is a symlink to `~/nixos-config`. So the chain is target -> `/nix/store/...-home-manager-files/<target>` -> `/nix/store/...-hm_<name>` -> `~/.flake/<path>` -> the repo file. `repoFileAll dir target` makes one such symlink per file that existed in `dir` at eval time
- Files read with `builtins.readFile` or `source = ./...` are copied into the store, so editing them needs `just switch`
- A module that takes no arguments is a plain attrset, not a function that ignores them (`_: { ... }`)
- Check the platform with `pkgs.stdenv.hostPlatform.isDarwin` or `.isLinux`, never by matching the `system` string
- Prefer a declarative nix-darwin or home-manager module (a launchd agent, a nix package) over imperative setup or a hand-cloned repo
- When a nix-managed symlink replaces an existing config dir, move the old one to `<dir>.bak`, never delete it. Only the user removes the `.bak`
- Scripts that run only on the user's machines can use zsh-isms. Keep POSIX `sh` for CI, containers, and anything distributed

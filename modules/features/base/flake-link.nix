{
  flake.modules.homeManager.base = { lib, config, ... }: {
    _module.args.repoFile =
      relPath: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.flake/${relPath}";

    home.activation.checkFlakeLink = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      # require ~/.flake to actually resolve to the repo. test -L alone would
      # pass a dangling symlink (repo moved/deleted), silently breaking every
      # mkOutOfStoreSymlink target, so check the resolved flake.nix instead.
      if ! test -e "$HOME/.flake/flake.nix"; then
        echo "ERROR: \$HOME/.flake does not resolve to the nixos-config repo." >&2
        if test -L "$HOME/.flake"; then
          echo "  it points to $(readlink "$HOME/.flake"), which is missing or not the repo." >&2
        fi
        echo "Fix: from inside the repo run: ln -sfn \$PWD ~/.flake" >&2
        exit 1
      fi
    '';
  };
}

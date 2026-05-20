{
  flake.modules.homeManager.base =
    { lib, config, ... }:
    {
      _module.args.repoFile =
        relPath: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.flake/${relPath}";

      home.activation.checkFlakeLink = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        if ! test -L "$HOME/.flake"; then
          echo "ERROR: \$HOME/.flake is not a symlink to the nixos-config repo." >&2
          echo "Fix: from inside the repo run: ln -s \$PWD ~/.flake" >&2
          exit 1
        fi
      '';
    };
}

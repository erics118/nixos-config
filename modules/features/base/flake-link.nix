{
  flake.modules.homeManager.base = { lib, config, ... }: {
    _module.args =
      let
        repoRoot = ../../..;
      in
      rec {
        repoFile =
          relPath: config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.flake/${relPath}";

        repoFileAll =
          relPath: targetPath:
          let
            sourceDir = repoRoot + "/${relPath}";
            relTo = f: lib.removePrefix "${toString sourceDir}/" (toString f);
          in
          lib.listToAttrs (
            map (
              f:
              let
                rel = relTo f;
              in
              lib.nameValuePair "${targetPath}/${rel}" { source = repoFile "${relPath}/${rel}"; }
            ) (lib.filesystem.listFilesRecursive sourceDir)
          );
      };

    # require ~/.flake to actually resolve to the repo. test -L alone would
    # pass a dangling symlink (repo moved/deleted), silently breaking every
    # mkOutOfStoreSymlink target, so check the resolved flake.nix instead.
    home.activation.checkFlakeLink = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
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

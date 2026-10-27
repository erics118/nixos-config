{
  flake.modules.homeManager.base =
    {
      lib,
      config,
      inputs,
      ...
    }:
    let
      # out-of-store symlink into the live checkout at ~/<repo>, so edits apply with no switch
      liveFile =
        repo: relPath:
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${repo}/${relPath}";

      # one liveFile link per git-tracked file present at eval time, so a new file needs a git add and a switch
      liveFileAll =
        repo: root: relPath: targetPath:
        let
          sourceDir = root + "/${relPath}";
          # a flake input root carries store context, which home.file names reject
          relTo =
            f: builtins.unsafeDiscardStringContext (lib.removePrefix "${toString sourceDir}/" (toString f));
        in
        lib.listToAttrs (
          map (
            f:
            let
              rel = relTo f;
            in
            lib.nameValuePair "${targetPath}/${rel}" { source = liveFile repo "${relPath}/${rel}"; }
          ) (lib.filesystem.listFilesRecursive sourceDir)
        );
    in
    {
      _module.args = {
        repoFile = liveFile "nixos-config";
        repoFileAll = liveFileAll "nixos-config" ../../..;
        privateFile = liveFile "nixos-config-private";
        privateFileAll = liveFileAll "nixos-config-private" inputs.nixos-config-private;
      };

      # a missing checkout silently breaks every mkOutOfStoreSymlink target into it
      home.activation.checkCheckouts = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        for repo in nixos-config nixos-config-private; do
          if ! test -e "$HOME/$repo/flake.nix"; then
            echo "ERROR: \$HOME/$repo is not a checkout of the $repo repo." >&2
            echo "Fix: git clone git@github.com:erics118/$repo ~/$repo" >&2
            exit 1
          fi
        done
      '';
    };
}

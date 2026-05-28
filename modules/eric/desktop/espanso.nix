{
  flake.modules.homeManager.base =
    { repoFile, lib, ... }:
    let
      managedFiles = [
        "accents"
        "keys"
        "latex"
        "typography"
      ];
    in
    {
      # live-symlinks so edits to espanso match files take effect without a rebuild
      home.file = lib.listToAttrs (
        map (name: {
          name = ".config/espanso/match/managed_${name}.yml";
          value.source = repoFile "modules/eric/desktop/espanso/${name}.yml";
        }) managedFiles
      );
    };
}

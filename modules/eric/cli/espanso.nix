{
  flake.modules.homeManager.base =
    { repoFile, lib, ... }:
    {
      # live-symlinks so edits to espanso match files take effect without a rebuild
      home.file =
        lib.genAttrs
          (map (f: ".config/espanso/match/managed_${f}") [
            "accents.yml"
            "keys.yml"
            "latex.yml"
            "typography.yml"
          ])
          (path: {
            source = repoFile "modules/eric/cli/files/espanso/${baseNameOf path}";
          });
    };
}

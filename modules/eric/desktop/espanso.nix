{
  flake.modules.homeManager.base =
    { lib, ... }:
    let
      managedFiles = [
        "accents"
        "keys"
        "latex"
        "typography"
      ];
    in
    {
      home.file = lib.listToAttrs (
        map (name: {
          name = ".config/espanso/match/managed_${name}.yml";
          value.source = ./espanso/${name}.yml;
        }) managedFiles
      );
    };
}

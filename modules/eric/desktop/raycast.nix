{
  flake.modules.homeManager.darwin = { repoFile, ... }: {
    home.file.".config/raycast/script-commands".source =
      repoFile "modules/eric/desktop/raycast/scripts";
  };
}

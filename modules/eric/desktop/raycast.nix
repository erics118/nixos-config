{
  flake.modules.homeManager.darwin = { repoFile, ... }: {
    # registered in raycast as a script directory
    home.file.".config/raycast/script-commands".source =
      repoFile "modules/eric/desktop/raycast/scripts";
  };
}

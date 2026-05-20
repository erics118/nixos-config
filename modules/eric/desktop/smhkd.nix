{
  flake.modules.homeManager.darwin =
    { repoFile, ... }:
    {
      home.file = {
        ".config/smhkd/smhkdrc".source = repoFile "modules/eric/desktop/smhkd/smhkdrc";
      };
    };
}

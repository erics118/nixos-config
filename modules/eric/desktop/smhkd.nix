{
  flake.modules.homeManager.base =
    { repoFile, ... }:
    {
      home.file = {
        ".config/smhkd/smhkdrc".source = repoFile "modules/eric/desktop/smhkd/smhkdrc";
      };
    };
}

{
  flake.modules.homeManager.darwin =
    { repoFile, ... }:
    {
      home.file = {
        ".config/yabai/yabairc".source = repoFile "modules/eric/desktop/yabai/yabairc";
        ".config/yabai/unmanaged_rules.sh".source =
          repoFile "modules/eric/desktop/yabai/unmanaged_rules.sh";
      };
    };
}

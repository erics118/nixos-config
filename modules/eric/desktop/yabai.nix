{
  flake.modules.homeManager.darwin = {
    home.file = {
      ".config/yabai/yabairc".source = ./yabai/yabairc;
      ".config/yabai/unmanaged_rules.sh".source = ./yabai/unmanaged_rules.sh;
    };
  };
}

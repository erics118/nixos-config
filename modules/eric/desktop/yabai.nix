{
  flake.modules.homeManager.darwin = {
    home.file = {
      ".config/yabai/yabairc".source = ./yabai/yabairc;
      ".config/yabai/unmanaged_rules.sh".source = ./yabai/unmanaged_rules.sh;
    };
  };

  flake.modules.darwin.base = {
    # empty config so the agent runs plain yabai, which reads ~/.config/yabai/yabairc
    # enableScriptingAddition generates /etc/sudoers.d/yabai with the store binary's
    # sha256, so `sudo yabai --load-sa` in yabairc keeps working across rebuilds
    services.yabai = {
      enable = true;
      enableScriptingAddition = true;
    };
  };
}

{
  flake.modules.homeManager.darwin = {
    home.file = {
      ".config/yabai/yabairc".source = ./yabai/yabairc;
      ".config/yabai/unmanaged_rules.sh".source = ./yabai/unmanaged_rules.sh;
    };
  };

  flake.modules.darwin.base = {
    # empty config so the agent runs plain yabai, which reads ~/.config/yabai/yabairc
    services.yabai = {
      enable = true;
      enableScriptingAddition = true;
    };

    # enableScriptingAddition keys its sudoers rule to the store path, but yabairc
    # calls `sudo yabai`, which resolves through PATH and never matches that rule.
    # grant the PATH-resolved binary too, or --load-sa silently asks for a password
    security.sudo.extraConfig = ''
      %admin ALL=(root) NOPASSWD: /run/current-system/sw/bin/yabai --load-sa
    '';
  };
}

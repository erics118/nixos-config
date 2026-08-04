{
  flake.modules.homeManager.darwin = {
    home.file = {
      ".config/yabai/yabairc".source = ./yabai/yabairc;
      ".config/yabai/unmanaged_rules.sh".source = ./yabai/unmanaged_rules.sh;
      # yabairc execs this on load and from the display_added/removed signals
      ".config/yabai/on_display_update" = {
        source = ./yabai/on_display_update;
        executable = true;
      };
    };
  };

  flake.modules.darwin.base = { config, lib, ... }: {
    # empty config so the agent runs plain yabai, which reads ~/.config/yabai/yabairc
    services.yabai = {
      enable = true;
      enableScriptingAddition = true;
    };

    launchd.user.agents.yabai.serviceConfig = {
      StandardOutPath = "/tmp/yabai_eric.out.log";
      StandardErrorPath = "/tmp/yabai_eric.err.log";
      EnvironmentVariables.PATH = lib.mkForce (
        "${config.services.yabai.package}/bin:"
        + builtins.replaceStrings [ "$HOME" "$USER" ] [ "/Users/eric" "eric" ] config.environment.systemPath
      );
    };

    # enableScriptingAddition keys its sudoers rule to the store path, but yabairc
    # calls `sudo yabai`, which resolves through PATH and never matches that rule.
    # grant the PATH-resolved binary too, or --load-sa silently asks for a password
    security.sudo.extraConfig = ''
      %admin ALL=(root) NOPASSWD: /run/current-system/sw/bin/yabai --load-sa
    '';
  };
}

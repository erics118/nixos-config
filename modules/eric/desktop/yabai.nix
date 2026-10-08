{
  flake.modules.homeManager.darwin = {
    home.file = {
      ".config/yabai/yabairc".source = ./yabai/yabairc.sh;
      ".config/yabai/unmanaged_rules.sh".source = ./yabai/unmanaged_rules.sh;
      # yabairc execs this on load and from the display_added/removed signals
      ".config/yabai/on_display_update.sh" = {
        source = ./yabai/on_display_update.sh;
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

    signedAgents.yabai = config.services.yabai.package;

    launchd.user.agents.yabai.serviceConfig = {
      # the label yabai's own --start-service/--stop-service manage
      Label = "com.asmvik.yabai";
      StandardOutPath = "/tmp/yabai_eric.out.log";
      StandardErrorPath = "/tmp/yabai_eric.err.log";
      EnvironmentVariables.PATH = lib.mkForce (
        "/usr/local/bin:"
        + builtins.replaceStrings [ "$HOME" "$USER" ] [ "/Users/eric" "eric" ] config.environment.systemPath
      );
    };

    # enableScriptingAddition keys its sudoers rule to the store binary and its hash
    # `sudo yabai` in yabairc finds /usr/local/bin/yabai first, the re-signed copy from signedAgents
    # grant the PATH-resolved binaries too, or --load-sa silently asks for a password
    security.sudo.extraConfig = ''
      %admin ALL=(root) NOPASSWD: /usr/local/bin/yabai --load-sa
      %admin ALL=(root) NOPASSWD: /run/current-system/sw/bin/yabai --load-sa
    '';
  };
}

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

  flake.modules.darwin.base =
    { config, lib, ... }:
    let
      # the agent runs a signed copy at a fixed path, since the Accessibility grant
      # is keyed to path and signature, and a store path changes on every rebuild
      signedYabai = "/usr/local/bin/yabai";
      # sha-1 of the usable yabai-cert, since an expired one shares the name
      yabaiCert = "E9CAB0F318EDCA0C217DA5AAB7893EBBFF51CD59";
    in
    {
      # empty config so the agent runs plain yabai, which reads ~/.config/yabai/yabairc
      services.yabai = {
        enable = true;
        enableScriptingAddition = true;
      };

      launchd.user.agents.yabai.serviceConfig = {
        # the label yabai's own --start-service/--stop-service manage
        Label = "com.asmvik.yabai";
        ProgramArguments = lib.mkForce [ signedYabai ];
        StandardOutPath = "/tmp/yabai_eric.out.log";
        StandardErrorPath = "/tmp/yabai_eric.err.log";
        EnvironmentVariables.PATH = lib.mkForce (
          "/usr/local/bin:"
          + builtins.replaceStrings [ "$HOME" "$USER" ] [ "/Users/eric" "eric" ] config.environment.systemPath
        );
      };

      # the cert lives in eric's login keychain, so eric signs a temp copy and root installs it
      # re-sign only when the store binary changes, since codesign can prompt for keychain access
      system.activationScripts.postActivation.text = ''
        yabai_src=${config.services.yabai.package}/bin/yabai
        if [ "$(cat ${signedYabai}.source 2>/dev/null)" != "$yabai_src" ]; then
          echo >&2 "signing yabai..."
          yabai_uid=$(id -u eric)
          yabai_tmp=$(launchctl asuser "$yabai_uid" sudo --user=eric mktemp -d)
          if launchctl asuser "$yabai_uid" sudo --user=eric sh -c 'cp "$1" "$2/yabai" && codesign -fs ${yabaiCert} "$2/yabai"' _ "$yabai_src" "$yabai_tmp"; then
            mkdir -p /usr/local/bin
            install -o root -g wheel -m 755 "$yabai_tmp/yabai" ${signedYabai}
            echo "$yabai_src" > ${signedYabai}.source
            # the agent's plist does not change, so launchd would keep running the old binary
            launchctl kickstart -k gui/"$yabai_uid"/com.asmvik.yabai 2>/dev/null || true
          else
            echo >&2 "warning: could not sign yabai with yabai-cert, keeping the previous ${signedYabai}"
          fi
          rm -rf "$yabai_tmp"
        fi
      '';

      # enableScriptingAddition keys its sudoers rule to the store path, but yabairc
      # calls `sudo yabai`, which resolves through PATH and never matches that rule.
      # grant the PATH-resolved binaries too, or --load-sa silently asks for a password
      security.sudo.extraConfig = ''
        %admin ALL=(root) NOPASSWD: ${signedYabai} --load-sa
        %admin ALL=(root) NOPASSWD: /run/current-system/sw/bin/yabai --load-sa
      '';
    };
}

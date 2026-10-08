{
  # macos keys privacy grants (accessibility, screen recording) to a binary's path and signature,
  # and a store path changes on every rebuild, so these agents run a signed copy at a fixed path
  flake.modules.darwin.base =
    { config, lib, ... }:
    let
      cfg = config.signedAgents;
      cert = config.signedAgentsCert;
    in
    {
      options.signedAgents = lib.mkOption {
        type = lib.types.attrsOf lib.types.package;
        default = { };
        description = "launchd user agents whose binary <package>/bin/<name> runs as a copy at /usr/local/bin/<name> signed with yabai-cert";
      };

      # read by `just install-local` too
      options.signedAgentsCert = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        # sha-1 of the usable yabai-cert, since an expired one shares the name
        default = "E9CAB0F318EDCA0C217DA5AAB7893EBBFF51CD59";
        description = "codesign identity for signedAgents";
      };

      config = {
        launchd.user.agents = lib.mapAttrs (name: _: {
          serviceConfig.ProgramArguments = lib.mkForce [ "/usr/local/bin/${name}" ];
        }) cfg;

        # the cert lives in eric's login keychain, so eric signs a temp copy and root installs it
        # re-sign only when the store binary changes, since codesign can prompt for keychain access
        system.activationScripts.postActivation.text = lib.concatStrings (
          lib.mapAttrsToList (
            name: package:
            let
              src = "${package}/bin/${name}";
              dst = "/usr/local/bin/${name}";
              label = config.launchd.user.agents.${name}.serviceConfig.Label;
            in
            ''
              if [ "$(cat ${dst}.source 2>/dev/null)" != "${src}" ]; then
                echo >&2 "signing ${name}..."
                agent_uid=$(id -u eric)
                agent_tmp=$(launchctl asuser "$agent_uid" sudo --user=eric mktemp -d)
                # --set-home, since activation exports HOME=~root and codesign finds keychains through HOME
                if launchctl asuser "$agent_uid" sudo --user=eric --set-home sh -c 'cp "$1" "$2/bin" && codesign -fs ${cert} "$2/bin"' _ "${src}" "$agent_tmp"; then
                  mkdir -p /usr/local/bin
                  install -o root -g wheel -m 755 "$agent_tmp/bin" ${dst}
                  echo "${src}" > ${dst}.source
                  # the agent's plist does not change, so launchd would keep running the old binary
                  launchctl kickstart -k gui/"$agent_uid"/${label} 2>/dev/null || true
                else
                  echo >&2 "warning: could not sign ${name} with yabai-cert, keeping the previous ${dst}"
                fi
                rm -rf "$agent_tmp"
              fi
            ''
          ) cfg
        );
      };
    };
}

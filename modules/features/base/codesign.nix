{
  # macos keys privacy grants (accessibility, screen recording) to a binary's path and signature,
  # and a store path changes on every rebuild, so these agents and apps run a signed copy at a fixed path
  flake.modules.darwin.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.signedAgents;
      # sha-1 of eric-codesign, so a later cert with the same name can't be picked
      cert = "7F88B029292C5FA6A0670ED0A87E77644B61AB4C";
    in
    {
      options.signedAgents = lib.mkOption {
        type = lib.types.attrsOf lib.types.package;
        default = { };
        description = "launchd user agents whose binary <package>/bin/<name> runs as a copy at /usr/local/bin/<name> signed with eric-codesign";
      };

      options.signedApps = lib.mkOption {
        type = lib.types.attrsOf lib.types.package;
        default = { };
        description = "apps whose bundle <package>/Applications/<name>.app installs as a copy at /Applications/<name>.app signed with eric-codesign, and whose bin goes on PATH";
      };

      config = {
        # the package minus its bundle, which would otherwise land unsigned in /Applications/Nix Apps
        environment.systemPackages = lib.mapAttrsToList (
          _: package:
          pkgs.symlinkJoin {
            name = "${package.name}-cli";
            paths = [ package ];
            # bin can hold relative links into the bundle, so relink it to the original package
            postBuild = ''
              rm -r $out/Applications $out/bin
              mkdir $out/bin
              ln -s ${package}/bin/* $out/bin
            '';
          }
        ) config.signedApps;

        launchd.user.agents = lib.mapAttrs (name: _: {
          serviceConfig.ProgramArguments = lib.mkForce [ "/usr/local/bin/${name}" ];
        }) cfg;

        # the cert lives in eric's login keychain, so eric signs a temp copy and root installs it
        # re-sign only when the store binary changes, since codesign can prompt for keychain access
        system.activationScripts.postActivation.text = lib.concatStrings (
          lib.mapAttrsToList (
            name: package:
            let
              src = "${package}/Applications/${name}.app";
              dst = "/Applications/${name}.app";
              # a marker inside the bundle would break its seal
              marker = "/Applications/.${name}.app.source";
            in
            ''
              if [ "$(cat ${marker} 2>/dev/null)" != "${src}" ]; then
                echo >&2 "signing ${name}.app..."
                agent_uid=$(id -u eric)
                agent_tmp=$(launchctl asuser "$agent_uid" sudo --user=eric mktemp -d)
                if launchctl asuser "$agent_uid" sudo --user=eric --set-home sh -c 'cp -R "$1" "$2" && chmod -R u+w "$2/$3" && codesign -f --deep -s ${cert} "$2/$3"' _ "${src}" "$agent_tmp" "${name}.app"; then
                  rm -rf "${dst}"
                  mv "$agent_tmp/${name}.app" "${dst}"
                  chown -R root:wheel "${dst}"
                  echo "${src}" > "${marker}"
                else
                  echo >&2 "warning: could not sign ${name}.app with eric-codesign, keeping the previous ${dst}"
                fi
                rm -rf "$agent_tmp"
              fi
            ''
          ) config.signedApps
          ++ lib.mapAttrsToList (
            name: package:
            let
              src = "${package}/bin/${name}";
              dst = "/usr/local/bin/${name}";
              marker = "/usr/local/bin/.${name}.source";
              label = config.launchd.user.agents.${name}.serviceConfig.Label;
            in
            ''
              if [ "$(cat ${marker} 2>/dev/null)" != "${src}" ]; then
                echo >&2 "signing ${name}..."
                agent_uid=$(id -u eric)
                agent_tmp=$(launchctl asuser "$agent_uid" sudo --user=eric mktemp -d)
                # --set-home, since activation exports HOME=~root and codesign finds keychains through HOME
                if launchctl asuser "$agent_uid" sudo --user=eric --set-home sh -c 'cp "$1" "$2/bin" && codesign -fs ${cert} "$2/bin"' _ "${src}" "$agent_tmp"; then
                  mkdir -p /usr/local/bin
                  install -o root -g wheel -m 755 "$agent_tmp/bin" ${dst}
                  echo "${src}" > ${marker}
                  # the agent's plist does not change, so launchd would keep running the old binary
                  launchctl kickstart -k gui/"$agent_uid"/${label} 2>/dev/null || true
                else
                  echo >&2 "warning: could not sign ${name} with eric-codesign, keeping the previous ${dst}"
                fi
                rm -rf "$agent_tmp"
              fi
            ''
          ) cfg
        );
      };
    };
}

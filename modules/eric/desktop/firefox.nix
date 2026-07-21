{
  flake.modules.homeManager.darwin =
    {
      inputs,
      lib,
      pkgs,
      repoFile,
      ...
    }:
    let
      base = "modules/eric/desktop/firefox";
      profile = "Library/Application Support/Firefox/Profiles/gcl3mics.dev-edition-default";
      fxAutoconfig = pkgs.applyPatches {
        name = "fx-autoconfig-patched";
        src = inputs.fx-autoconfig-src;
        patches = [ ./firefox/fx-autoconfig.patch ];
      };
    in
    {
      home.file = {
        "${profile}/chrome/JS".source = repoFile "${base}/chrome/JS";
        "${profile}/chrome/CSS".source = repoFile "${base}/chrome/CSS";
        "${profile}/chrome/resources".source = repoFile "${base}/chrome/resources";
        "${profile}/chrome/utils".source = "${fxAutoconfig}/profile/chrome/utils";
        "${profile}/chrome/userChrome.css".source = repoFile "${base}/chrome/userChrome.css";
        "${profile}/user.js".source = repoFile "${base}/user.js";
      };

      # Firefox Developer Edition is an application bundle in /Applications,
      # not a Nix Firefox package. Reinstall fx-autoconfig's two program files
      # whenever the Home Manager generation is activated.
      home.activation.firefoxDeveloperEditionAutoconfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        resources="/Applications/Firefox Developer Edition.app/Contents/Resources"
        source_config="${fxAutoconfig}/program/config.js"
        source_prefs="${fxAutoconfig}/program/defaults/pref/config-prefs.js"

        if test -d "$resources"; then
          $DRY_RUN_CMD /bin/mkdir -p "$resources/defaults/pref"

          if ! /usr/bin/cmp -s "$source_config" "$resources/config.js"; then
            $DRY_RUN_CMD /usr/bin/install -m 0644 \
              "$source_config" \
              "$resources/config.js"
          fi

          if ! /usr/bin/cmp -s "$source_prefs" "$resources/defaults/pref/config-prefs.js"; then
            $DRY_RUN_CMD /usr/bin/install -m 0644 \
              "$source_prefs" \
              "$resources/defaults/pref/config-prefs.js"
          fi
        fi
      '';
    };
}

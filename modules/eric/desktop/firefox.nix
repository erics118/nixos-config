let
  profileFiles =
    profile:
    { inputs, repoFile, ... }:
    let
      base = "modules/eric/desktop/firefox";
    in
    {
      home.file = {
        "${profile}/chrome/JS".source = repoFile "${base}/chrome/JS";
        "${profile}/chrome/CSS".source = repoFile "${base}/chrome/CSS";
        "${profile}/chrome/resources".source = repoFile "${base}/chrome/resources";
        "${profile}/chrome/utils".source = "${inputs.fx-autoconfig-src}/profile/chrome/utils";
        "${profile}/chrome/userChrome.css".source = repoFile "${base}/chrome/userChrome.css";
        "${profile}/user.js".source = repoFile "${base}/user.js";
      };
    };
in
{
  flake.modules.homeManager.darwin =
    { inputs, lib, ... }:
    let
      fxAutoconfig = inputs.fx-autoconfig-src;
    in
    {
      imports = [
        (profileFiles "Library/Application Support/Firefox/Profiles/gcl3mics.dev-edition-default")
      ];

      # a firefox update replaces the app bundle and drops these files
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

  flake.modules.homeManager.hyprland = profileFiles ".config/mozilla/firefox/ob0g1466.dev-edition-default";

  flake.modules.nixos.hyprland = { inputs, pkgs, ... }: {
    programs.firefox = {
      # developer edition, as on macos, since it installs the unsigned sidebery fork.
      # the wrapper's autoconfig.js names mozilla.cfg but leaves the sandbox on
      package = pkgs.firefox-devedition.override {
        extraAutoConfig = ''pref("general.config.sandbox_enabled", false);'';
      };
      autoConfigFiles = [ "${inputs.fx-autoconfig-src}/program/config.js" ];
    };
  };
}

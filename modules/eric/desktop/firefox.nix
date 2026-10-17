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
  flake.modules.homeManager.darwin = {
    imports = [
      (profileFiles "Library/Application Support/Firefox/Profiles/gcl3mics.dev-edition-default")
    ];
  };

  flake.modules.darwin.base = { inputs, pkgs, ... }: {
    # nix-darwin has no programs.firefox, so the wrapper takes the autoconfig directly
    environment.systemPackages = [
      (pkgs.firefox-devedition.override {
        extraAutoConfig = ''pref("general.config.sandbox_enabled", false);'';
        extraPrefsFiles = [ "${inputs.fx-autoconfig-src}/program/config.js" ];
      })
    ];
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

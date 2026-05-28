{ inputs, ... }:
{
  flake.modules.darwin.base = {
    imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

    nix-homebrew = {
      user = "eric";
      enable = true;
      autoMigrate = true;
    };

    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = false;
        cleanup = "zap"; # or "none"
        upgrade = false;
      };
      global = {
        brewfile = true;
      };

      taps = [
        "felixkratz/formulae"
        "koekeishiya/formulae"
        "erics118/tap"
      ];

      brews = [
        {
          name = "macos-trash";
          link = true;
        }
        "felixkratz/formulae/sketchybar"
        "felixkratz/formulae/svim"
        "koekeishiya/formulae/skhd"
        {
          name = "koekeishiya/formulae/yabai";
          args = [ "HEAD" ];
        }
        "erics118/tap/goku"
        "llvm"
      ];

      casks = [
        "1password"
        "font-sf-pro"
      ];

      masApps = { };
    };
  };
}

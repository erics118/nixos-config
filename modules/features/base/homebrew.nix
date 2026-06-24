{ inputs, ... }:
let
  head = name: {
    inherit name;
    args = [ "HEAD" ];
  };
in
{
  flake.modules.darwin.base = {
    imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

    nix-homebrew = {
      user = "eric";
      enable = true;
      enableRosetta = false;
      autoMigrate = true;
      mutableTaps = true;

      # we need to trust taps before we can use them
      trust = {
        formulae = [
          # "asmvik/formulae/yabai"
        ];
        casks = [ ];
        commands = [ ];
        taps = [
          "felixkratz/formulae"
          "asmvik/formulae"
          "erics118/tap"
          "docker/tap"
        ];
      };
    };

    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = true;
        cleanup = "zap"; # or "none"
        upgrade = true;
      };
      global = {
        brewfile = true;
      };

      taps = [
        "felixkratz/formulae"
        "asmvik/formulae"
        "erics118/tap"
        "docker/tap"
      ];

      brews = [
        {
          name = "macos-trash";
          link = true;
        }
        (head "erics118/tap/sketchybar")
        (head "erics118/tap/smhkd")
        (head "asmvik/formulae/yabai")

        "erics118/tap/goku"
        "llvm"

        "railway"
        "vercel-cli"
        "supabase"
      ];

      casks = [
        "1password"
        "font-sf-pro"
        "docker/tap/sbx"
      ];

      masApps = { };
    };
  };
}

{ inputs, ... }: {
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
        formulae = [ ];
        casks = [ ];
        commands = [ ];
        taps = [ ];
      };
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

      taps = [ ];

      brews = [
        "openssl"
        "cliclick"
      ];

      casks = [ ];

      masApps = { };
    };
  };
}

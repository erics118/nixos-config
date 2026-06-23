{
  flake.modules =
    let
      # shared nh clean policy
      keepSince = "7d";
      keepCount = "5";
    in
    {
      nixos.base = {
        nix.settings.auto-optimise-store = true;

        programs.nh = {
          enable = true;
          clean = {
            enable = true;
            dates = "Sun 03:00";
            extraArgs = "--keep-since ${keepSince} --keep ${keepCount} --optimise";
          };
        };
      };

      # darwin has no programs.nh.clean, so run the same policy via launchd
      darwin.base = { pkgs, ... }: {
        nix.settings.auto-optimise-store = true;

        launchd.daemons = {
          nh-clean.serviceConfig = {
            ProgramArguments = [
              "${pkgs.nh}/bin/nh"
              "clean"
              "all"
              "--keep-since"
              keepSince
              "--keep"
              keepCount
              "--optimise"
            ];
            StartCalendarInterval = [
              {
                Weekday = 0;
                Hour = 3;
                Minute = 0;
              }
            ];
            RunAtLoad = false;
            StandardOutPath = "/var/log/nh-clean.log";
            StandardErrorPath = "/var/log/nh-clean.log";
          };

          # deprioritize the nix build daemon
          nix-daemon.serviceConfig.Nice = -10;
        };
      };

      homeManager.base = { config, ... }: {
        programs.nh = {
          enable = true;
          flake = "${config.home.homeDirectory}/.flake";
        };
      };
    };
}

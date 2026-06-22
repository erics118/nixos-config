{
  flake.modules =
    let
      # shared nh clean policy
      keepSince = "14d";
      keepCount = "10";
    in
    {
      nixos.base = {
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

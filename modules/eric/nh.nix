# run weekly nh clean at 3am on sundays
{
  flake.modules = {
    # use programs.nh to set it up on nixos
    nixos.base = {
      programs.nh = {
        enable = true;
        clean = {
          enable = true;
          dates = "Sun 03:00";
          extraArgs = "--keep-since 14d --keep 10 --optimise";
        };
      };
    };

    # use a launchd daemon on darwin
    darwin.base = { pkgs, ... }: {
      launchd.daemons."nh-clean" = {
        serviceConfig = {
          ProgramArguments = [
            "${pkgs.nh}/bin/nh"
            "clean"
            "all"
            "--keep-since"
            "14d"
            "--keep"
            "10"
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

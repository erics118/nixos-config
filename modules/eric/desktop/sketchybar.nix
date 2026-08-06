{
  flake.modules.homeManager.darwin = { repoFile, ... }: {
    # single live-symlink: edits to lua/scripts take effect without a rebuild
    # C helpers continue to build in place via helpers/*/makefile
    home.file.".config/sketchybar".source = repoFile "modules/eric/desktop/sketchybar";
  };

  flake.modules.darwin.base =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      environment.systemPackages = [ pkgs.sketchybar ];

      launchd.user.agents.sketchybar = {
        serviceConfig = {
          ProgramArguments = [ (lib.getExe pkgs.sketchybar) ];
          WorkingDirectory = "/Users/eric/.config/sketchybar";
          EnvironmentVariables = {
            LANG = "en_US.UTF-8";
            PATH = config.launchdUserPath;
          };
          RunAtLoad = true;
          KeepAlive = true;
          ProcessType = "Interactive";
          StandardOutPath = "/tmp/sketchybar_eric.out.log";
          StandardErrorPath = "/tmp/sketchybar_eric.err.log";
        };
      };
    };
}

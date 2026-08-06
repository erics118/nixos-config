{
  flake.modules.homeManager.darwin = {
    home.file = {
      ".config/smhkd/smhkdrc".source = ./smhkd/smhkdrc;
    };
  };

  flake.modules.darwin.base =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      environment.systemPackages = [ pkgs.smhkd ];

      launchd.user.agents.smhkd = {
        serviceConfig = {
          ProgramArguments = [ (lib.getExe pkgs.smhkd) ];
          EnvironmentVariables = {
            PATH = config.launchdUserPath;
          };
          RunAtLoad = true;
          KeepAlive = true;
          ProcessType = "Interactive";
          StandardOutPath = "/tmp/smhkd_eric.out.log";
          StandardErrorPath = "/tmp/smhkd_eric.err.log";
        };
      };
    };
}

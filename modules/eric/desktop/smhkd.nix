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
      signedAgents.smhkd = pkgs.smhkd;

      launchd.user.agents.smhkd = {
        serviceConfig = {
          # the label smhkd's own --start-service/--stop-service manage
          Label = "com.erics118.smhkd";
          ProgramArguments = [ (lib.getExe pkgs.smhkd) ];
          EnvironmentVariables = {
            PATH = config.launchdUserPath;
          };
          RunAtLoad = true;
          KeepAlive = true;
          ProcessType = "Interactive";
          Nice = -20;
          StandardOutPath = "/tmp/smhkd_eric.out.log";
          StandardErrorPath = "/tmp/smhkd_eric.err.log";
        };
      };
    };
}

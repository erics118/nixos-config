{
  flake.modules.homeManager.darwin = {
    home.file = {
      ".config/smhkd/smhkdrc".source = ./smhkd/smhkdrc;
    };
  };

  flake.modules.darwin.base = { pkgs, lib, ... }: {
    environment.systemPackages = [ pkgs.smhkd ];

    launchd.user.agents.smhkd = {
      serviceConfig = {
        ProgramArguments = [ (lib.getExe pkgs.smhkd) ];
        EnvironmentVariables = {
          PATH = "/Users/eric/.local/bin:/Users/eric/.nix-profile/bin:/etc/profiles/per-user/eric/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
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

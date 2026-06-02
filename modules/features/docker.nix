{
  flake.modules.nixos.docker =
    { pkgs, ... }:
    {
      virtualisation.docker = {
        enable = true;

        autoPrune = {
          enable = true;
          dates = "weekly";
          flags = [
            "--all"
            "--volumes"
          ];
        };

        daemon.settings = {
          live-restore = true;

          features = {
            buildkit = true;
          };
        };
      };

      users.users.eric.extraGroups = [ "docker" ];

      environment.systemPackages = with pkgs; [ docker-compose ];
    };
}

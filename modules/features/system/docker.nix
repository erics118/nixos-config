{
  flake.modules.nixos.docker = { pkgs, ... }: {
    virtualisation.docker = {
      enable = true;

      autoPrune = {
        enable = true;
        dates = "weekly";
        # no --volumes: it deletes the anonymous volumes of stopped containers, data included
        flags = [ "--all" ];
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

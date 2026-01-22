{ pkgs, inputs, ... }:

let
  compose2nix-pkg = inputs.compose2nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  virtualisation.docker = {
    enable = true;

    # Automatic cleanup of unused resources
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [
        "--all" # Remove all unused images, not just dangling ones
        "--volumes" # Also prune volumes
      ];
    };

    # Daemon configuration optimizations
    daemon.settings = {
      live-restore = true;

      features = {
        buildkit = true;
      };
    };
  };

  # Add docker group (NixOS modules automatically merge extraGroups lists)
  users.users.eric.extraGroups = [ "docker" ];

  # Docker-related system packages
  environment.systemPackages = with pkgs; [
    docker-compose
    compose2nix-pkg
  ];
}

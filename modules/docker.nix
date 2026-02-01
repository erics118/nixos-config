{ pkgs, inputs, ... }:

let
  compose2nix-pkg = inputs.compose2nix.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
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

  environment.systemPackages = with pkgs; [
    docker-compose
    compose2nix-pkg
  ];
}

{ config, ... }:
let
  m = config.flake.modules;
in
{
  configurations.nixos.squid.module = {
    imports = [
      m.nixos.base
      m.nixos.ssh-server
      m.nixos.sops
      m.nixos.docker
      m.nixos.tailscale
      m.nixos.cachix-push
      ../../machines/squid.nix
    ];
    nixpkgs.hostPlatform = "x86_64-linux";
  };

  configurations.homeManager."eric@squid" = {
    system = "x86_64-linux";
    module = {
      imports = [ m.homeManager.base ];
      home.username = "eric";
      home.homeDirectory = "/home/eric";
    };
  };
}

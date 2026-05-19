{ config, ... }:
let
  m = config.flake.modules;
in
{
  configurations.nixos.nixos-vm.module = {
    imports = [
      m.nixos.base
      m.nixos.desktop-gnome
      m.nixos.ssh-server
      m.nixos.sops
      m.nixos.tailscale
      ../../machines/nixos-vm.nix
    ];
    nixpkgs.hostPlatform = "aarch64-linux";
  };

  configurations.homeManager."eric@nixos-vm" = {
    system = "aarch64-linux";
    module = {
      imports = [ m.homeManager.base ];
      home.username = "eric";
      home.homeDirectory = "/home/eric";
    };
  };
}

{ config, lib, ... }:
let
  m = config.flake.modules;
in
{
  configurations.nixos.narwhal.module = {
    imports = [
      m.nixos.base
      m.nixos.ssh-server
      m.nixos.sops
      m.nixos.docker
      m.nixos.tailscale
      m.nixos.cachix-push
      m.nixos.desktop-gnome
      m.nixos.desktop-hyprland
      ./_hardware/x86_64-narwhal.nix
    ];
    nixpkgs.hostPlatform = "x86_64-linux";
    networking.hostName = "narwhal";
    networking.networkmanager.enable = true;

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.systemd-boot.configurationLimit = 5;
  
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.graphics.enable = true;

    hardware.nvidia = {
      modesetting.enable = true;
      open = false;
      nvidiaSettings = true;
      # package = config.boot.kernelPackages.nvidiaPackages.stable;

    };

  };

  configurations.homeManager."eric@narwhal" = {
    system = "x86_64-linux";
    module = {
      imports = [ m.homeManager.base m.homeManager.desktop-gnome m.homeManager.desktop-hyprland ];
      home.username = "eric";
      home.homeDirectory = "/home/eric";
    };
  };
}

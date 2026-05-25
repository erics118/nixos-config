{ config, lib, ... }:
let
  m = config.flake.modules;
in
{
  configurations.nixos.narwhal.module = { pkgs, ... }: {
    imports = [
      m.nixos.base
      m.nixos.ssh-server
      m.nixos.sops
      m.nixos.docker
      m.nixos.tailscale
      m.nixos.cachix-push
      m.nixos.base-linux
      m.nixos.desktop-hyprland
      ./_hardware/x86_64-narwhal.nix
    ];

    home-manager.users.eric.imports = [
      m.homeManager.desktop-hyprland
    ];

    nixpkgs.hostPlatform = "x86_64-linux";
    networking.hostName = "narwhal";
    networking.networkmanager.enable = true;

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.systemd-boot.configurationLimit = 5;
  
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.graphics = {
      enable = true;
      extraPackages = [ pkgs.nvidia-vaapi-driver ];
    };

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      open = true;
      nvidiaSettings = true;
    };

  };

  configurations.homeManager."eric@narwhal" = {
    system = "x86_64-linux";
    module = {
      imports = [ m.homeManager.base m.homeManager.desktop-hyprland ];
      home.username = "eric";
      home.homeDirectory = "/home/eric";
    };
  };
}

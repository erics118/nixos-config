{ config, mkHome, ... }:
let
  m = config.flake.modules;
in
{
  configurations.nixos.narwhal.module =
    { ... }:
    {
      imports = [
        m.nixos.base
        m.nixos.ssh-server
        m.nixos.sops
        m.nixos.docker
        m.nixos.tailscale
        m.nixos.cachix-push
        m.nixos.desktop-linux
        m.nixos.desktop-hyprland
        m.nixos.hp-printer
        m.nixos.nvidia
        ./_hardware/x86_64-narwhal.nix
      ];

      home-manager.users.eric.imports = [ m.homeManager.desktop-hyprland ];

      nixpkgs.hostPlatform = "x86_64-linux";
      networking.hostName = "narwhal";

      boot.loader = {
        systemd-boot = {
          enable = true;
          configurationLimit = 5;
        };
        efi.canTouchEfiVariables = true;
      };
    };

  configurations.homeManager."eric@narwhal" = mkHome {
    system = "x86_64-linux";
    homeDirectory = "/home/eric";
    imports = [ m.homeManager.desktop-hyprland ];
  };
}

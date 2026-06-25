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
      m.nixos.adguardhome
      m.nixos.homepage
      m.nixos.scrutiny
      m.nixos.gatus
      m.nixos.immich
      m.nixos.glances
      m.nixos.cachix-push
      m.nixos.hyprland
      m.nixos.hp-printer
      m.nixos.nvidia
      m.nixos.caddy
      m.nixos.nas
      ./_hardware/x86_64-narwhal.nix
    ];

    home-manager.users.eric.imports = [ m.homeManager.hyprland ];

    nixpkgs.hostPlatform = "x86_64-linux";

    networking.hostName = "narwhal";

    # wake-on-lan on the wired NIC
    networking.interfaces.enp5s0.wakeOnLan.enable = true;

    # enable firewall. everything is exposed through tailscale
    networking.firewall = {
      enable = lib.mkForce true;
      trustedInterfaces = [ "tailscale0" ];
    };

    # dont sleep
    systemd.sleep.settings.Sleep = {
      AllowSuspend = "no";
    };

    fileSystems."/mnt/external" = {
      device = "/dev/disk/by-uuid/a4e08c36-c690-4d1d-a8dc-7b207e1d3418";
      fsType = "ext4";
      options = [
        "nofail"
        "noatime"
        "x-systemd.device-timeout=10s"
      ];
    };

    boot = {
      loader = {
        systemd-boot = {
          enable = true;
          configurationLimit = 5;
          consoleMode = "max";
        };
        efi.canTouchEfiVariables = true;
      };

      initrd = {
        systemd.enable = true;
      };
    };

    systemd.services.NetworkManager-wait-online.enable = false;

    # narwhal no working public IPv6, so we prefer IPv6, and ignore the router advertisement on LAN
    environment.etc."gai.conf".text = ''
      precedence ::ffff:0:0/96  100
    '';
    boot.kernel.sysctl."net.ipv6.conf.wlo1.accept_ra" = 0;
  };
}

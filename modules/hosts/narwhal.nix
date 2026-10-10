{ config, ... }:
let
  m = config.flake.modules;
in
{
  configurations.nixos.narwhal.module = { config, ... }: {
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
      m.nixos.auto-upgrade
      m.nixos.ntfy-client
      m.nixos.eriz
      m.nixos.hyprland
      m.nixos.sunshine
      m.nixos.hp-printer
      m.nixos.nvidia
      m.nixos.caddy
      m.nixos.nas
      ./_hardware/x86_64-narwhal.nix
    ];

    home-manager.users.eric.imports = [ m.homeManager.hyprland ];

    nixpkgs.hostPlatform = "x86_64-linux";

    networking.hostName = "narwhal";

    # ntfy runs on turtle at its own domain; link out, no local caddy vhost
    homepageTiles = [
      {
        name = "ntfy";
        group = "Infrastructure";
        href = "https://${config.ntfyHost}";
        proxy = false;
        description = "Push notifications";
        icon = "ntfy.svg";
      }
    ];

    # host-specific key ~/.ssh/id_ed25519_narwhal on orca, on top of the shared base key
    users.users.eric.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFi4z8EKPTUWxi0lI3voCfQVq8hIZJdtL/NAWzsG4+py eric@macb"
    ];

    # wake-on-lan on the wired NIC
    networking.interfaces.enp5s0.wakeOnLan.enable = true;

    # persistent machine-check, memory, pcie error log
    hardware.rasdaemon.enable = true;

    # dont sleep
    systemd.sleep.settings.Sleep = {
      AllowSuspend = "no";
    };

    # autologin into hyprland at boot: sunshine is a user service on
    # graphical-session.target, so streaming needs a live session
    services.greetd.settings.initial_session = {
      command = "uwsm start hyprland-uwsm.desktop";
      user = "eric";
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
          # the OEM ESP is only 200M and can't grow without repartitioning
          # each generation's kernel plus initrd is about 42M, so recompute before raising this
          configurationLimit = 3;
          consoleMode = "max";
        };
        efi.canTouchEfiVariables = true;
      };

      initrd = {
        systemd.enable = true;
      };
    };

    systemd.services.NetworkManager-wait-online.enable = false;

    # narwhal has no working public IPv6, so prefer IPv4 addresses
    environment.etc."gai.conf".text = ''
      precedence ::ffff:0:0/96  100
    '';

    environment.systemPackages = [ config.boot.kernelPackages.perf ];
  };
}

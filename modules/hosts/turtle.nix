{ inputs, config, ... }:
let
  m = config.flake.modules;
in
{
  configurations.nixos.turtle.module = { pkgs, config, ... }: {
    imports = [
      m.nixos.base
      m.nixos.ssh-server
      m.nixos.sops
      m.nixos.docker
      m.nixos.tailscale
      m.nixos.glances
      m.nixos.auto-upgrade
      m.nixos.ntfy
      m.nixos.ntfy-client
      m.nixos.eriz
      inputs.disko.nixosModules.disko
      ./_hardware/aarch64-turtle.nix
      ./_hardware/aarch64-turtle-disko.nix
    ];
    nixpkgs.hostPlatform = "aarch64-linux";

    networking = {
      hostName = "turtle";
      # public-facing oracle box: only ssh, plus mosh's udp 60000-61000 from programs.mosh
      firewall.allowedTCPPorts = [ 22 ];
    };

    # host-specific key ~/.ssh/id_ed25519_oracle_turtle on orca, on top of the shared base key
    users.users.eric.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEueqORxrYmEGwiC+DerpbNP0BUC8Byeetkq4M0ZPEUZ eric@orca"
    ];

    boot.loader.systemd-boot = {
      enable = true;
      configurationLimit = 5;
    };
    boot.loader.efi.canTouchEfiVariables = true;

    environment.systemPackages = [ pkgs.cloudflared ];

    # docker's published ports skip the nixos firewall, so publish on loopback by default
    # a container meant to be public needs an explicit -p 0.0.0.0:...
    virtualisation.docker.daemon.settings.ip = "127.0.0.1";

    # default root-only mode: cloudflared gets it through LoadCredential, read as root
    sops.secrets."cloudflared/turtle-tunnel" = { };

    # outbound tunnel, no inbound ports opened. public services fan out here:
    # add ingress."<name>.eriz.cc".service = "http://localhost:<port>" and a matching CNAME
    services.cloudflared.enable = true;
    services.cloudflared.tunnels."91d785c6-c697-495c-a0aa-3e01037a3de2" = {
      credentialsFile = config.sops.secrets."cloudflared/turtle-tunnel".path;
      default = "http_status:404";
      ingress.${config.ntfyHost}.service = "http://${config.services.ntfy-sh.settings.listen-http}";
    };
  };
}

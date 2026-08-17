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
      inputs.disko.nixosModules.disko
      ./_hardware/aarch64-turtle.nix
      ./_hardware/aarch64-turtle-disko.nix
    ];
    nixpkgs.hostPlatform = "aarch64-linux";

    networking = {
      hostName = "turtle";
      # public-facing oracle box: only ssh reachable
      firewall.allowedTCPPorts = [ 22 ];
    };

    # host-specific key, on top of the shared base key
    users.users.eric.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEueqORxrYmEGwiC+DerpbNP0BUC8Byeetkq4M0ZPEUZ eric@orca"
    ];

    boot.loader.systemd-boot = {
      enable = true;
      configurationLimit = 5;
    };
    boot.loader.efi.canTouchEfiVariables = true;

    environment.systemPackages = [ pkgs.cloudflared ];

    # cloudflared runs as a DynamicUser, so the creds file must be world-readable
    sops.secrets."cloudflared/turtle-tunnel".mode = "0444";

    # outbound tunnel, no inbound ports opened. public services fan out here:
    # add "<name>.eriz.cc".service = "http://localhost:<port>" and a matching CNAME
    services.cloudflared.enable = true;
    services.cloudflared.tunnels."91d785c6-c697-495c-a0aa-3e01037a3de2" = {
      credentialsFile = config.sops.secrets."cloudflared/turtle-tunnel".path;
      default = "http_status:404";
      ingress."ntfy.eriz.cc".service = "http://localhost:2586";
    };
  };
}

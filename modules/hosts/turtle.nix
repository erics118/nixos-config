{
  inputs,
  config,
  lib,
  mkHome,
  ...
}:
let
  m = config.flake.modules;
in
{
  configurations.nixos.turtle.module = {
    imports = [
      m.nixos.base
      m.nixos.ssh-server
      m.nixos.tailscale
      inputs.disko.nixosModules.disko
      ./_hardware/aarch64-oracle.nix
      ./_hardware/aarch64-oracle-disko.nix
    ];
    nixpkgs.hostPlatform = "aarch64-linux";

    networking = {
      hostName = "turtle";
      # public-facing oracle box: only ssh reachable
      firewall = {
        enable = lib.mkForce true;
        allowedTCPPorts = [ 22 ];
      };
    };

    # public-facing host: key auth only
    services.openssh.settings.PasswordAuthentication = lib.mkForce false;

    # host-specific key, on top of the shared base key
    users.users.eric.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEueqORxrYmEGwiC+DerpbNP0BUC8Byeetkq4M0ZPEUZ eric@orca"
    ];

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
  };

  configurations.homeManager."eric@turtle" = mkHome { system = "aarch64-linux"; };
}

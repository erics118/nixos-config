{ lib, config, ... }:
let
  inherit (config) tailnetDomain;

  # per machine: its own ~/.ssh/id_ed25519.pub, and its /etc/ssh/ssh_host_ed25519_key.pub
  hosts = {
    orca = {
      userKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKYegGpRKtmZCW3UNYOym55wAyRqi2JiVLgUUmbiWCf1";
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILcaA/ckStXVJ7I42oOSySzVsBxiXDrpZHerkR+5CZKn";
    };
    narwhal = {
      userKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBIaXnl7v3GUEMwnWD2O829pBZRWxQwi6feMGve3usbl";
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAQhmq1QJis1gOCyy4CtAMg7y/CAlNGj5VFZB1Zn6HjR";
    };
    turtle = {
      userKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMPDU+X6Zr0OH02OfUU5szk0eU5d7wgQZDnqoHlUVhJS";
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM9ymMdoKvzooTIUc2ucvk7lKTV9GIFdsh4Myaulujik";
    };
  };

  shared = {
    users.users.eric.openssh.authorizedKeys.keys = lib.mapAttrsToList (
      name: host: "${host.userKey} eric@${name}"
    ) hosts;

    # by the tailnet name the private ssh config connects with, plus the trailing-dot form tailscale ssh uses
    programs.ssh.knownHosts = lib.mapAttrs (name: host: {
      hostNames = [
        "${name}.${tailnetDomain}"
        "${name}.${tailnetDomain}."
      ];
      publicKey = host.hostKey;
    }) hosts;
  };
in
{
  flake.modules.nixos.base = {
    imports = [ shared ];
  };
  flake.modules.darwin.base = {
    imports = [ shared ];
  };
}

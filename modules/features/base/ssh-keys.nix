let
  shared = {
    # each machine's own ~/.ssh/id_ed25519
    users.users.eric.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKYegGpRKtmZCW3UNYOym55wAyRqi2JiVLgUUmbiWCf1 eric@orca"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBIaXnl7v3GUEMwnWD2O829pBZRWxQwi6feMGve3usbl eric@narwhal"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMPDU+X6Zr0OH02OfUU5szk0eU5d7wgQZDnqoHlUVhJS eric@turtle"
    ];

    # each machine's /etc/ssh/ssh_host_ed25519_key.pub, by every name the private ssh config connects with
    programs.ssh.knownHosts = {
      orca = {
        hostNames = [ "orca.dolphin-sailfin.ts.net" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILcaA/ckStXVJ7I42oOSySzVsBxiXDrpZHerkR+5CZKn";
      };
      narwhal = {
        hostNames = [ "narwhal.dolphin-sailfin.ts.net" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAQhmq1QJis1gOCyy4CtAMg7y/CAlNGj5VFZB1Zn6HjR";
      };
      turtle = {
        hostNames = [ "turtle.dolphin-sailfin.ts.net" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM9ymMdoKvzooTIUc2ucvk7lKTV9GIFdsh4Myaulujik";
      };
    };
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

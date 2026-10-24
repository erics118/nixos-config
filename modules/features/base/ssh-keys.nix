let
  shared = {
    # each machine's own ~/.ssh/id_ed25519
    users.users.eric.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKYegGpRKtmZCW3UNYOym55wAyRqi2JiVLgUUmbiWCf1 eric@orca"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBIaXnl7v3GUEMwnWD2O829pBZRWxQwi6feMGve3usbl eric@narwhal"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMPDU+X6Zr0OH02OfUU5szk0eU5d7wgQZDnqoHlUVhJS eric@turtle"
    ];
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

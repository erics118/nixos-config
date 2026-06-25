{ config, ... }:
let
  m = config.flake.modules;
in
{
  configurations.darwin.orca.module = {
    imports = [
      m.darwin.base
      m.darwin.sops
    ];
    nixpkgs.hostPlatform = "aarch64-darwin";

    networking.hostName = "orca";

    home-manager.users.eric.imports = [ m.homeManager.darwin ];
  };
}

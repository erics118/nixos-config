{ config, mkHome, ... }:
let
  m = config.flake.modules;
in
{
  configurations.darwin.orca.module = {
    imports = [ m.darwin.base ];
    nixpkgs.hostPlatform = "aarch64-darwin";

    networking.hostName = "orca";

    home-manager.users.eric.imports = [ m.homeManager.darwin ];
  };

  configurations.homeManager."eric@orca" = mkHome {
    system = "aarch64-darwin";
    homeDirectory = "/Users/eric";
    imports = [ m.homeManager.darwin ];
  };
}

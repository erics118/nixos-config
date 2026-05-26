{ config, ... }:
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

  configurations.homeManager."eric@orca" = {
    system = "aarch64-darwin";
    module = {
      imports = [
        m.homeManager.base
        m.homeManager.darwin
      ];
      home.username = "eric";
      home.homeDirectory = "/Users/eric";
    };
  };
}

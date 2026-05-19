{ config, ... }:
let
  m = config.flake.modules;
in
{
  configurations.darwin.macbook.module = {
    imports = [
      m.darwin.base
      ../../machines/macbook.nix
    ];
    nixpkgs.hostPlatform = "aarch64-darwin";
  };

  configurations.homeManager."eric@macbook" = {
    system = "aarch64-darwin";
    module = {
      imports = [ m.homeManager.base ];
      home.username = "eric";
      home.homeDirectory = "/Users/eric";
    };
  };
}

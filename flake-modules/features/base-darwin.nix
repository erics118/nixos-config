{ inputs, ... }:
{
  flake.modules.darwin.base = {
    imports = [
      inputs.home-manager.darwinModules.home-manager
      inputs.nix-homebrew.darwinModules.nix-homebrew
      ../../modules/darwin.nix
    ];

    nix-homebrew = {
      user = "eric";
      enable = true;
      autoMigrate = true;
    };

    nixpkgs = {
      config.allowUnfree = true;
      overlays = builtins.attrValues (import ../../overlays { inherit inputs; });
    };
  };
}

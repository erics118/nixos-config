{ inputs, ... }:
{
  flake.modules.nixos.base = {
    imports = [
      inputs.catppuccin.nixosModules.catppuccin
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
      ../../modules/linux-common.nix
      ../../modules/users-eric.nix
    ];

    nixpkgs = {
      config.allowUnfree = true;
      overlays = builtins.attrValues (import ../../overlays { inherit inputs; });
    };
  };
}

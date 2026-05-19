{ inputs, ... }:
{
  flake.modules.homeManager.base = {
    imports = [
      ../../users/eric
      inputs.catppuccin.homeModules.catppuccin
      inputs.sops-nix.homeManagerModules.sops
    ];
  };
}

{ inputs, ... }:
{
  flake.modules.homeManager.base = {
    imports = [
      inputs.catppuccin.homeModules.catppuccin
      inputs.sops-nix.homeManagerModules.sops
    ];
  };
}

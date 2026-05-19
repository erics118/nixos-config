{ inputs, ... }:
{
  flake.modules.homeManager.base = {
    imports = [
      ../_home/eric
      inputs.catppuccin.homeModules.catppuccin
      inputs.sops-nix.homeManagerModules.sops
    ];
  };
}

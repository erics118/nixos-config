{ inputs, config, ... }:
let
  hmBase = config.flake.modules.homeManager.base;
  hmWiring = {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = { inherit inputs; };
      backupFileExtension = "bak";
      users.eric.imports = [ hmBase ];
    };
  };
in
{
  flake.modules.homeManager.base = {
    imports = [
      inputs.catppuccin.homeModules.catppuccin
      inputs.sops-nix.homeManagerModules.sops

      # configure nix-index with comma
      inputs.nix-index-database.homeModules.default
      {
        programs.nix-index-database.comma.enable = true;
        programs.nix-index.enable = true;
      }
    ];
  };

  flake.modules.nixos.base = hmWiring;
  flake.modules.darwin.base = hmWiring;
}

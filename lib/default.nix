{
  inputs,
  nixpkgs,
  home-manager,
}:

let
  # import overlays
  overlays = import ../overlays { inherit inputs; };
  overlaysList = builtins.attrValues overlays;

  # create pkgs with overlays for a given system
  mkPkgs =
    system:
    import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = overlaysList;
    };

  # nixOS module to configure nixpkgs with overlays
  nixpkgsModule = {
    nixpkgs = {
      config.allowUnfree = true;
      overlays = overlaysList;
    };
  };

  # common NixOS modules for all machines
  commonNixosModules = [
    nixpkgsModule
    inputs.catppuccin.nixosModules.catppuccin
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
  ];

  # Shared home-manager modules for user eric
  ericHomeModules = [
    ../users/eric
    inputs.catppuccin.homeModules.catppuccin
  ];

  # Helper to create standalone home-manager configuration
  mkHome =
    {
      system,
      modules ? [ ],
      homeDirectory ? null,
    }:
    let
      defaultHomeDir =
        if nixpkgs.lib.strings.hasSuffix "darwin" system then "/Users/eric" else "/home/eric";
    in
    home-manager.lib.homeManagerConfiguration {
      pkgs = mkPkgs system;
      extraSpecialArgs = { inherit inputs; };
      modules =
        ericHomeModules
        ++ modules
        ++ [
          {
            home.username = "eric";
            home.homeDirectory = if homeDirectory != null then homeDirectory else defaultHomeDir;
          }
        ];
    };

  # Helper to create NixOS configuration
  mkNixos =
    { system, modules }:
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = commonNixosModules ++ modules;
    };

in
{
  inherit
    overlays
    mkHome
    mkNixos
    ;
}

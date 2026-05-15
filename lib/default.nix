{
  inputs,
  nixpkgs,
  home-manager,
  darwin,
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

  # common darwin modules for all macOS machines
  commonDarwinModules = [
    nixpkgsModule
    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
    {
      nix-homebrew = {
        user = "eric";
        enable = true;
        autoMigrate = true;
      };
    }
  ];

  # Shared home-manager modules for user eric
  ericHomeModules = [
    ../users/eric
    inputs.catppuccin.homeModules.catppuccin
    inputs.sops-nix.homeManagerModules.sops
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

  # Helper to create macOS (nix-darwin) configuration
  mkDarwin =
    { system, modules }:
    darwin.lib.darwinSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = commonDarwinModules ++ modules;
    };

in
{
  inherit
    overlays
    mkHome
    mkNixos
    mkDarwin
    ;
}

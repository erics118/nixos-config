{
  description = "NixOS configuration for nixos";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-ros-overlay = {
      url = "github:lopsided98/nix-ros-overlay/master";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:erics118/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    catppuccin = {
      url = "github:catppuccin/nix/release-25.11";
    };

    compose2nix = {
      url = "github:aksiksi/compose2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # ensure extra cachix substituters
  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      lib = import ./lib { inherit inputs nixpkgs home-manager; };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      flake = {
        inherit (lib) overlays;

        nixosConfigurations = {
          squid = lib.mkNixos {
            system = "x86_64-linux";
            modules = [ ./machines/squid.nix ];
          };

          nixos-vm = lib.mkNixos {
            system = "aarch64-linux";
            modules = [ ./machines/nixos-vm.nix ];
          };
        };

        homeConfigurations = {
          "eric@squid" = lib.mkHome "x86_64-linux";
          "eric@nixos-vm" = lib.mkHome "aarch64-linux";
        };
      };
    };
}

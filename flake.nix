{
  description = "NixOS configuration for nixos";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    llm-agents.url = "github:numtide/llm-agents.nix";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
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
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    compose2nix = {
      url = "github:aksiksi/compose2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wezterm-src = {
      url = "github:erics118/wezterm?ref=eric&dir=nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nia-rules = {
      url = "github:nozomio-labs/nia-rules-for-agents";
      flake = false;
    };

    adversarial-review = {
      url = "github:alecnielsen/adversarial-review";
      flake = false;
    };
  };

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      home-manager,
      darwin,
      treefmt-nix,
      ...
    }:
    let
      lib = import ./lib {
        inherit
          inputs
          nixpkgs
          home-manager
          darwin
          ;
      };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ treefmt-nix.flakeModule ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      perSystem =
        { config, pkgs, ... }:
        {
          treefmt = {
            projectRootFile = "flake.nix";

            settings.excludes = [
              "secrets/**"
            ];

            programs.nixfmt.enable = true;
            programs.deadnix.enable = true;
            programs.statix.enable = true;
            programs.prettier.enable = true;
            programs.shfmt.enable = true;
            programs.shellcheck.enable = true;
            programs.just.enable = true;
            programs.taplo.enable = true;
          };

          devShells.default = pkgs.mkShell {
            packages = [ config.treefmt.build.wrapper ];
          };
        };

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

        darwinConfigurations = {
          macbook = lib.mkDarwin {
            system = "aarch64-darwin";
            modules = [ ./machines/macbook.nix ];
          };
        };

        homeConfigurations = {
          "eric@squid" = lib.mkHome { system = "x86_64-linux"; };
          "eric@nixos-vm" = lib.mkHome { system = "aarch64-linux"; };
          "eric@macbook" = lib.mkHome { system = "aarch64-darwin"; };
        };
      };
    };
}

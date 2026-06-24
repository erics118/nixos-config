{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # pure nix helper, doesn't depend on nixpkgs
    import-tree.url = "github:vic/import-tree";

    # private bundle: sops secrets, recipients, host-specific config.
    # exports flakeModules.default (import-tree of its ./modules).
    nixos-config-private = {
      url = "git+ssh://git@github.com/erics118/nixos-config-private.git";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.treefmt-nix.follows = "treefmt-nix";
      inputs.import-tree.follows = "import-tree";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # doesn't depend on nixpkgs
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # don't follow nixpkgs: nixvim is built/tested against its own pin, so
    # following ours rebuilds neovim+plugins off-cache and warns (nixpkgs.source)
    nixvim = {
      url = "github:erics118/nixvim";
      inputs.flake-parts.follows = "flake-parts";
      inputs.treefmt-nix.follows = "treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # explicitly don't follow nixpkgs
    catppuccin.url = "github:catppuccin/nix";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wezterm-src = {
      # we aren't using github: because dir= will result in unstable hashes
      url = "git+https://github.com/erics118/wezterm?ref=eric&dir=nix&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland-contrib = {
      url = "github:hyprwm/contrib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    adversarial-review = {
      url = "github:alecnielsen/adversarial-review";
      flake = false;
    };

    # explicitly don't follow nixpkgs for binary cache hits
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.flake-parts.follows = "flake-parts";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      { config, ... }:
      let
        overlays = builtins.attrValues config.flake.overlays;
      in
      {
        imports = [
          inputs.flake-parts.flakeModules.modules
          inputs.treefmt-nix.flakeModule
          (inputs.import-tree ./modules)
          inputs.nixos-config-private.flakeModules.default
        ];

        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
        ];

        perSystem =
          {
            config,
            pkgs,
            system,
            ...
          }:
          {
            # always allow unfree
            _module.args.pkgs = import inputs.nixpkgs {
              inherit system overlays;
              config.allowUnfree = true;
            };

            devShells = {
              default = pkgs.mkShell { packages = [ config.treefmt.build.wrapper ]; };

              sketchybar = pkgs.mkShell {
                packages = with pkgs; [
                  lua-language-server
                  stylua
                  lua5_5
                  clang-tools
                  gnumake
                ];
              };
            };

            treefmt = {
              projectRootFile = "flake.nix";

              settings = {
                excludes = [
                  "secrets/**"
                  "result"
                  "result-*"
                  "flake.lock"
                  "*.age"
                ];
                on-unmatched = "info";
                # stylua config (indent type/width) lives in stylua.toml

                # keep top-level inputs' direct follows tidy (`inputs.X.follows`).
                # --depth 1 stays at direct children: deeper follows here only
                # pull pinned/cache inputs (nixvim.nixvim, llm-agents.*) off
                # their own nixpkgs, which we don't want. --no-lock because the
                # treefmt check runs in the nix sandbox with no network
                formatter.flake-edit = {
                  command = pkgs.flake-edit;
                  options = [
                    "--non-interactive"
                    "--no-lock"
                    "follow"
                    "--depth"
                    "1"
                  ];
                  includes = [ "flake.nix" ];
                };
              };

              programs = {
                nixfmt.enable = true;
                nixfmt.strict = true;
                deadnix.enable = true;
                statix.enable = true;

                shfmt.enable = true;

                prettier.enable = true;
                just.enable = true;
                taplo.enable = true;
                yamlfmt = {
                  enable = true;
                  settings.formatter.retain_line_breaks_single = true;
                };
                jsonfmt.enable = true;

                stylua.enable = true;
                clang-format.enable = true;
              };
            };
          };
      }
    );
}

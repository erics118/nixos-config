{
  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # pure nix helper, doesn't depend on nixpkgs
    import-tree.url = "github:vic/import-tree";

    # private bundle: sops secrets, recipients, host-specific config
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

    direnv-instant = {
      url = "github:Mic92/direnv-instant";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.treefmt-nix.follows = "treefmt-nix";
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

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wezterm-src = {
      url = "github:erics118/wezterm/main?dir=nix";
      # keeps its own nixpkgs to match the build in the erics118-wezterm cache
      # flake-edit.toml stops the formatter adding a follows
    };

    goku-src = {
      url = "github:erics118/GokuRakuJoudo";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    hyprland-contrib = {
      url = "github:hyprwm/contrib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    apple-fonts = {
      url = "github:Lyndeno/apple-fonts.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fx-autoconfig-src = {
      url = "github:MrOtherGuy/fx-autoconfig";
      flake = false;
    };

    smhkd-src = {
      url = "github:erics118/smhkd";
      flake = false;
    };

    front-src = {
      url = "github:erics118/front";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sketchybar-src = {
      url = "github:erics118/SketchyBar";
      flake = false;
    };

    yabai-src = {
      url = "github:erics118/yabai";
      flake = false;
    };

    mosh-src = {
      url = "github:erics118/mosh";
      flake = false;
    };

    # needs the netrc from modules/features/base/nix-common.nix until rex's first release
    rex = {
      url = "https://pkgs.superlogical.com/rex/nix/preview.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    smart-splits-backend-tmux-src = {
      url = "github:smart-splits-nvim/backend-tmux";
      flake = false;
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

        perSystem = { system, ... }: {
          # always allow unfree
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system overlays;
            config.allowUnfree = true;
          };
        };
      }
    );
}

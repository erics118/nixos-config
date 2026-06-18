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

    nixvim = {
      url = "github:erics118/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
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
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        (inputs.import-tree ./modules)
        inputs.nixos-config-private.flakeModules.default
      ];
    };
}

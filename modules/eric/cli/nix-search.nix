{
  # interactive fuzzy search over nixpkgs / NixOS / home-manager
  flake.modules.homeManager.base = { pkgs, ... }: {
    home.packages = [
      pkgs.nix-search-tv
      (pkgs.writeShellApplication {
        name = "ns";
        runtimeInputs = with pkgs; [
          fzf
          nix-search-tv
        ];
        text = builtins.readFile ./ns.sh;
      })
    ];
  };
}

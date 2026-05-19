{ inputs, pkgs, ... }:
{
  networking.hostName = "macbook";

  users.users.eric = {
    name = "eric";
    home = "/Users/eric";
    shell = pkgs.zsh;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    users.eric = {
      imports = [
        ../users/eric
        inputs.catppuccin.homeModules.catppuccin
        inputs.sops-nix.homeManagerModules.sops
      ];
    };
  };
}

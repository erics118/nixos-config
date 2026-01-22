{
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ../users/eric/sops.nix
  ];

  users.users.eric = {
    isNormalUser = true;
    description = "eric";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEZe2bb+e+CkJyE9johAfKiIcIaf20EtKPmS+bK/I+ZJ eric@eric.local"
    ];
  };

  nix.settings = {
    trusted-users = [ "eric" ];
  };

  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;
    extraSpecialArgs = { inherit inputs; };
    users.eric = {
      imports = [
        ../users/eric/home-manager.nix
        inputs.catppuccin.homeModules.catppuccin
        # inputs.sops-nix.homeModules.sops
      ];
    };
  };
}

{ inputs, config, ... }:
let
  hmBase = config.flake.modules.homeManager.base;
  hmWiring = {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = { inherit inputs; };
      backupFileExtension = "bak";
      users.eric.imports = [ hmBase ];
    };
  };
in
{
  flake.modules.homeManager.base = { pkgs, ... }: {
    # the module default builds ports from a separate nixpkgs instance
    # building them from our pkgs avoids evaluating nixpkgs twice
    catppuccin.sources = (import "${inputs.catppuccin}/default.nix" { inherit pkgs; }).packages;

    imports = [
      inputs.catppuccin.homeModules.catppuccin

      # configure nix-index with comma
      inputs.nix-index-database.homeModules.default
      {
        programs.nix-index-database.comma.enable = true;
        programs.nix-index.enable = true;
      }
    ];

    # skip evaluating home-manager's option docs for home-configuration.nix(5)
    manual.manpages.enable = false;

    # let sops cli automatically use default ssh id_ed25519 key for age-ssh decryption
    home.sessionVariables.SOPS_AGE_SSH_PRIVATE_KEY_FILE = "$HOME/.ssh/id_ed25519";
  };

  flake.modules.nixos.base = hmWiring;
  flake.modules.darwin.base = hmWiring;
}

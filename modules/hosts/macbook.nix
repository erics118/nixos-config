{ inputs, config, ... }:
let
  m = config.flake.modules;
in
{
  configurations.darwin.macbook.module =
    { pkgs, ... }:
    {
      imports = [
        m.darwin.base
      ];
      nixpkgs.hostPlatform = "aarch64-darwin";

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
            ../_home/eric
            inputs.catppuccin.homeModules.catppuccin
            inputs.sops-nix.homeManagerModules.sops
          ];
        };
      };
    };

  configurations.homeManager."eric@macbook" = {
    system = "aarch64-darwin";
    module = {
      imports = [ m.homeManager.base ];
      home.username = "eric";
      home.homeDirectory = "/Users/eric";
    };
  };
}

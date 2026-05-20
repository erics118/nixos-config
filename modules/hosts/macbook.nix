{ inputs, config, ... }:
let
  m = config.flake.modules;
in
{
  configurations.darwin.macbook.module =
    { pkgs, ... }:
    {
      imports = [ m.darwin.base ];
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
        users.eric.imports = [
          m.homeManager.base
          m.homeManager.darwin
        ];
      };
    };

  configurations.homeManager."eric@macbook" = {
    system = "aarch64-darwin";
    module = {
      imports = [
        m.homeManager.base
        m.homeManager.darwin
      ];
      home.username = "eric";
      home.homeDirectory = "/Users/eric";
    };
  };
}

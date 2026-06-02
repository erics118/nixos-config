{
  lib,
  config,
  inputs,
  withSystem,
  ...
}:
let
  mkHome =
    {
      system,
      homeDirectory,
      imports ? [ ],
    }:
    {
      inherit system;
      module = {
        imports = [ config.flake.modules.homeManager.base ] ++ imports;
        home.username = "eric";
        home.homeDirectory = homeDirectory;
      };
    };
in
{
  options.configurations.homeManager = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options = {
          system = lib.mkOption { type = lib.types.str; };
          module = lib.mkOption { type = lib.types.deferredModule; };
        };
      }
    );
    default = { };
  };

  config = {
    _module.args = { inherit mkHome; };

    flake.homeConfigurations = lib.mkIf (config.configurations.homeManager != { }) (
      lib.flip lib.mapAttrs config.configurations.homeManager (
        _name:
        { system, module }:
        withSystem system (
          { pkgs, ... }:
          inputs.home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            extraSpecialArgs = { inherit inputs; };
            modules = [ module ];
          }
        )
      )
    );
  };
}

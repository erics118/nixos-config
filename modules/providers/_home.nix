# standalone home-manager provider
# to use, add `configurations.homeManager.<name> = mkHome {...}`
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
      imports ? [ ],
    }:
    {
      inherit system;
      module = { pkgs, ... }: {
        imports = [ config.flake.modules.homeManager.base ] ++ imports;
        home.username = "eric";
        home.homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/eric" else "/home/eric";
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

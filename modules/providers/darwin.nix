{
  lib,
  config,
  inputs,
  ...
}:
{
  options.configurations.darwin = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options.module = lib.mkOption {
          type = lib.types.deferredModule;
        };
      }
    );
    default = { };
  };

  config.flake.darwinConfigurations = lib.mkIf (config.configurations.darwin != { }) (
    lib.flip lib.mapAttrs config.configurations.darwin (
      _name:
      { module }:
      inputs.darwin.lib.darwinSystem {
        modules = [ module ];
        specialArgs = { inherit inputs; };
      }
    )
  );
}

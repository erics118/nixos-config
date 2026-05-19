{
  lib,
  config,
  inputs,
  ...
}:
{
  options.configurations.nixos = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options.module = lib.mkOption {
          type = lib.types.deferredModule;
        };
      }
    );
    default = { };
  };

  config.flake.nixosConfigurations = lib.mkIf (config.configurations.nixos != { }) (
    lib.flip lib.mapAttrs config.configurations.nixos (
      _name:
      { module }:
      inputs.nixpkgs.lib.nixosSystem {
        modules = [ module ];
        specialArgs = { inherit inputs; };
      }
    )
  );
}

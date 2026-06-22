# expose every host toplevel and home activation as a flake check
# so `nix flake check` builds everything
{ lib, config, ... }: {
  perSystem = { system, ... }: {
    checks =
      let
        # keep only the configs whose build is for this system, then prefix
        # the names so they don't collide across classes
        forSystem =
          prefix: configs: toDrv:
          lib.mapAttrs' (name: cfg: lib.nameValuePair "${prefix}-${name}" (toDrv cfg)) (
            lib.filterAttrs (_: cfg: (toDrv cfg).system == system) configs
          );
      in
      lib.mkMerge [
        (forSystem "nixos" config.flake.nixosConfigurations (c: c.config.system.build.toplevel))
        (forSystem "darwin" config.flake.darwinConfigurations (c: c.config.system.build.toplevel))
        (forSystem "home" config.flake.homeConfigurations (c: c.activationPackage))
      ];
  };
}

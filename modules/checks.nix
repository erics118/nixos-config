# expose this system's host toplevels and the devShell as flake checks
# so `nix flake check` builds them. CI's runner matrix covers the other systems
{ lib, config, ... }: {
  perSystem = { system, self', ... }: {
    checks =
      let
        # keep only the configs whose build is for this system, then prefix
        # the names so they don't collide across classes
        forSystem =
          prefix: configs: toDrv:
          lib.mapAttrs' (name: cfg: lib.nameValuePair "${prefix}-${name}" (toDrv cfg)) (
            lib.filterAttrs (_: cfg: cfg.config.nixpkgs.hostPlatform.system == system) configs
          );
      in
      lib.mkMerge [
        (forSystem "nixos" config.flake.nixosConfigurations (c: c.config.system.build.toplevel))
        (forSystem "darwin" config.flake.darwinConfigurations (c: c.config.system.build.toplevel))
        # flake check only evaluates devShells, so build it here to catch a broken HYPR_STUBS
        { devShell = self'.devShells.default; }
      ];
  };
}

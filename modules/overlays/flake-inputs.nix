{ inputs, ... }: {
  # aliases 'pkgs.inputs.${flake}' to the flake's legacyPackages if non-empty, else its packages
  # eg: pkgs.inputs.hyprland-contrib.grimblast
  flake.overlays.flake-inputs = final: _: {
    inputs = builtins.mapAttrs (
      _: flake:
      let
        legacyPackages = (flake.legacyPackages or { }).${final.stdenv.hostPlatform.system} or { };
        packages = (flake.packages or { }).${final.stdenv.hostPlatform.system} or { };
      in
      if legacyPackages != { } then legacyPackages else packages
    ) inputs;
  };
}

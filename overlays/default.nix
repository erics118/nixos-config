{ inputs }:

# each attribute is an overlay that is applied to nixpkgs
{
  # aliases 'pkgs.inputs.${flake}' to the flake's packages
  # eg: pkgs.inputs.nixvim.default
  flake-inputs = final: _: {
    inputs = builtins.mapAttrs (
      _: flake:
      let
        legacyPackages = (flake.legacyPackages or { }).${final.stdenv.hostPlatform.system} or { };
        packages = (flake.packages or { }).${final.stdenv.hostPlatform.system} or { };
      in
      if legacyPackages != { } then legacyPackages else packages
    ) inputs;
  };

  # adds pkgs.unstable for nixpkgs-unstable packages
  # eg: pkgs.unstable.package-name
  unstable = final: _: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final) system;
      config.allowUnfree = true;
    };
  };

  # rust toolchain overlay
  rust = inputs.rust-overlay.overlays.default;
}

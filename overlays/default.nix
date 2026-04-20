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

  # rust toolchain overlay
  rust = inputs.rust-overlay.overlays.default;

  # custom wezterm fork (temporarily disabled)
  wezterm =
    final: prev:
    let
      inherit (final.stdenv.hostPlatform) system;
    in
    {
      wezterm = inputs.wezterm-src.packages.${system}.default.overrideAttrs (old: {
        # version = "erics118-custom";
        env = (old.env or { }) // {
          CC_aarch64_apple_darwin = "${prev.stdenv.cc.cc}/bin/clang";
        };
      });
    };

}

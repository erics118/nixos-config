{ inputs, ... }:
{
  # custom wezterm fork, overriding the one from nixpkgs globally
  flake.overlays.wezterm =
    final: _:
    let
      inherit (final.stdenv.hostPlatform) system;
    in
    {
      wezterm = inputs.wezterm-src.packages.${system}.default.overrideAttrs (old: {
        # src already points to my fork, so we just override the version
        version = old.version + "-eric";
        __intentionallyOverridingVersion = true;
      });
    };
}

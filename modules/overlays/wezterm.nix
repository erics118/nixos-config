{ inputs, ... }:
{
  # custom wezterm fork, overriding the one from nixpkgs globally
  flake.overlays.wezterm =
    final: _:
    let
      inherit (final.stdenv.hostPlatform) system;
    in
    {
      wezterm = inputs.wezterm-src.packages.${system}.default;
    };
}

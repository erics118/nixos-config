{ inputs, ... }: {
  # custom wezterm fork, overriding the one from nixpkgs globally.
  # taken unmodified, so it matches the build the fork's ci pushes to erics118-wezterm
  flake.overlays.wezterm =
    final: _:
    let
      inherit (final.stdenv.hostPlatform) system;
    in
    {
      wezterm = inputs.wezterm-src.packages.${system}.default;
    };
}

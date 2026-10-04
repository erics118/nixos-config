{ inputs, ... }: {
  # goku fork, overrides global one
  flake.overlays.goku = final: _: {
    goku = inputs.goku-src.packages.${final.stdenv.hostPlatform.system}.default;
  };
}

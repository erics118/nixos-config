{ inputs, ... }: {
  flake.overlays.front = final: _: {
    front = inputs.front-src.packages.${final.stdenv.hostPlatform.system}.default;
  };
}

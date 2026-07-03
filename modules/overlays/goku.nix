{
  # goku fork, overrides global one
  flake.overlays.goku = final: prev: {
    goku = prev.goku.overrideAttrs (old: {
      version = "0.8.1-eric";
      __intentionallyOverridingVersion = true;
      src = final.fetchurl {
        url = "https://github.com/erics118/GokuRakuJoudo/releases/download/v0.8.1/goku-aarch64-apple-darwin.zip";
        hash = "sha256-BwbNgAB4uAa6dFMlOE775y21x1WqIORaSGE63zYY3Rw=";
      };
      # fork zip is flat, upstream's contains a goku/ dir
      sourceRoot = ".";
      meta = old.meta // {
        mainProgram = "goku";
      };
    });
  };
}

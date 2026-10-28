{
  flake.overlays.ccache =
    _: prev:
    prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
      # the tests need elfutils, which is linux-only, so with them on ccache can't evaluate on darwin
      ccache = prev.ccache.overrideAttrs { doCheck = false; };
    };
}

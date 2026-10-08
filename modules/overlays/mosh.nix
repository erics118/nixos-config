{ inputs, ... }: {
  # mosh from the erics118/mosh fork (branch eric): DECSCUSR cursor shape, OSC 52
  # clipboard, undercurl/underline color, dim/strikethrough, unicode width fixes,
  # network hardening, and a readable disconnect-bar color (all baked into the fork)
  flake.overlays.mosh = _final: prev: {
    mosh = prev.mosh.overrideAttrs {
      version = "1.4.0-eric";
      __intentionallyOverridingVersion = true;
      src = inputs.mosh-src;
    };
  };
}

{ inputs, ... }: {
  # mosh from the erics118/mosh fork (branch eric): DECSCUSR cursor shape, OSC 52
  # clipboard, undercurl/underline color, dim/strikethrough, unicode width fixes,
  # network hardening, and a readable disconnect-bar color (all baked into the fork)
  flake.overlays.mosh = _final: prev: {
    mosh = prev.mosh.overrideAttrs (old: {
      version = "1.4.0-eric";
      __intentionallyOverridingVersion = true;
      src = inputs.mosh-src;
      # nixpkgs backports upstream commit eee1a8cf onto 1.4.0; the fork's base
      # already has it, so drop that patch and keep the nixpkgs path patches
      patches = builtins.filter (p: !prev.lib.hasInfix "eee1a8cf" (toString p)) old.patches;
    });
  };
}

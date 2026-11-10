{
  flake.overlays.zizmor = _: prev: {
    # nixpkgs' cargo setup hook makes aws-lc-sys require a system aws-lc, which the package lacks
    # nixpkgs pr 584921 fixes it upstream, drop this once nixos-unstable has it
    zizmor = prev.zizmor.overrideAttrs (old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [ prev.pkg-config ];
      buildInputs = old.buildInputs ++ [ prev.aws-lc ];
    });
  };
}

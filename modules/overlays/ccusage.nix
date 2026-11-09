{
  flake.overlays.ccusage = _: prev: {
    # nixpkgs' cargo setup hook makes zstd-sys probe pkg-config for libzstd, which the package lacks
    ccusage = prev.ccusage.overrideAttrs (old: {
      buildInputs = old.buildInputs ++ [ prev.zstd ];
    });
  };
}

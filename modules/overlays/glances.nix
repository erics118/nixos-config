_: {
  # glances test_phys_core_returns_int is broken
  flake.overlays.glances = _: prev: {
    glances = prev.glances.overrideAttrs (old: {
      disabledTests = (old.disabledTests or [ ]) ++ [ "test_phys_core_returns_int" ];
    });
  };
}

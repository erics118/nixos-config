{ inputs, ... }: {
  # jankyborders fork, overrides global one
  flake.overlays.jankyborders = _final: prev: {
    jankyborders = prev.jankyborders.overrideAttrs (old: {
      version = old.version + "-eric";
      __intentionallyOverridingVersion = true;
      # fork orders borders one level above their window, so a raised window can't cover them
      src = inputs.jankyborders-src;
    });
  };
}

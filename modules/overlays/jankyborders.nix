{ inputs, ... }: {
  # jankyborders fork, overrides global one
  flake.overlays.jankyborders = _final: prev: {
    jankyborders = prev.jankyborders.overrideAttrs (old: {
      version = old.version + "-eric";
      __intentionallyOverridingVersion = true;
      # fork draws each border as four edge windows, so screenshot window pickers select the window
      # with a yabai sa that supports ordering groups, edges ride in their window's group at its level
      src = inputs.jankyborders-src;
    });
  };
}

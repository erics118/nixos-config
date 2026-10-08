{ inputs, ... }: {
  # sketchybar fork, overrides global one
  flake.overlays.sketchybar = _final: prev: {
    sketchybar = prev.sketchybar.overrideAttrs (old: {
      version = old.version + "-eric";
      __intentionallyOverridingVersion = true;
      # fork's eric branch carries fixes not yet in an upstream release
      src = inputs.sketchybar-src;
      # binary reports upstream version
      doInstallCheck = false;
    });
  };
}

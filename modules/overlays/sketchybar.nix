{ inputs, ... }: {
  # sketchybar fork, overrides global one
  flake.overlays.sketchybar = _final: prev: {
    sketchybar = prev.sketchybar.overrideAttrs (old: {
      version = old.version + "-eric";
      __intentionallyOverridingVersion = true;
      # eric branch, feat: optionally use typographical width
      src = inputs.sketchybar-src;
      # binary reports upstream version
      doInstallCheck = false;
    });
  };
}

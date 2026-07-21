{ inputs, ... }: {
  # track HEAD instead of releases
  flake.overlays.yabai = _final: prev: {
    yabai = prev.yabai.overrideAttrs {
      version = "HEAD";
      __intentionallyOverridingVersion = true;
      src = inputs.yabai-src;
      # binary reports the upstream version, not the -unstable suffix
      doInstallCheck = false;
    };
  };
}

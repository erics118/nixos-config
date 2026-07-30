{ inputs, ... }: {
  # track HEAD instead of releases
  flake.overlays.yabai = _final: prev: {
    yabai = prev.yabai.overrideAttrs (old: {
      version = "HEAD";
      __intentionallyOverridingVersion = true;
      src = inputs.yabai-src;
      # binary reports the upstream version, not the -unstable suffix
      doInstallCheck = false;

      # nixpkgs strips the LC_UUID from the payload, but macOS 27 requires it
      # so we remove that stripping step
      postPatch = old.postPatch + ''
        substituteInPlace makefile --replace-fail " -Wl,-no_uuid" ""
      '';
    });
  };
}

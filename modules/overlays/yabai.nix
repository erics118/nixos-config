{ inputs, ... }: {
  # build the erics118/yabai fork, which carries the macOS 27 support upstream lacks
  flake.overlays.yabai = _final: prev: {
    yabai = prev.yabai.overrideAttrs (old: {
      version = "HEAD";
      __intentionallyOverridingVersion = true;
      src = inputs.yabai-src;
      # binary reports the upstream version, not the -unstable suffix
      doInstallCheck = false;

      # the makefile's default target is a debug build (-O0 -g, asserts on)
      # install is its release target (-DNDEBUG -O3) and still only writes bin/
      # clean first, since nix's fixed mtimes make any leftover src/osax/*_bin.c look up to date
      buildFlags = [
        "clean"
        "install"
      ];

      # nixpkgs strips the LC_UUID from the payload, but macOS 27 requires it
      # so we remove that stripping step
      # NixOS/nixpkgs#549299 fixes this upstream, and the assert fails once the pinned nixpkgs has it
      postPatch =
        assert prev.lib.assertMsg (prev.lib.hasInfix "-Wl,-no_uuid'" old.postPatch)
          "nixpkgs includes NixOS/nixpkgs#549299, so drop the yabai postPatch override in modules/overlays/yabai.nix";
        old.postPatch
        + ''
          substituteInPlace makefile --replace-fail " -Wl,-no_uuid" ""
        '';
    });
  };
}

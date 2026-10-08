{ inputs, ... }: {
  # build the erics118/yabai fork, which carries the macOS 27 support upstream lacks
  flake.overlays.yabai = _final: prev: {
    yabai = prev.yabai.overrideAttrs {
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
    };
  };
}

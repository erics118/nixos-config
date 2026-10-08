{ inputs, ... }: {
  # build the erics118/yabai fork, which carries the macOS 27 support upstream lacks
  flake.overlays.yabai = _final: prev: {
    yabai = prev.yabai.overrideAttrs {
      version = "HEAD";
      __intentionallyOverridingVersion = true;
      src = inputs.yabai-src;
      # binary reports the upstream version, not HEAD
      doInstallCheck = false;

      # the makefile's default target is a debug build (-O0 -g, asserts on)
      # install is its release target (-DNDEBUG -O3) and still only writes bin/
      # src/osax/*_bin.c is gitignored, so leftovers only arrive from a local checkout via the justfile's install-local
      # clean first, since nix's fixed mtimes make those leftovers look up to date
      buildFlags = [
        "clean"
        "install"
      ];
    };
  };
}

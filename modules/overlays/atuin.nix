{
  flake.overlays.atuin =
    _: prev:
    prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
      # the e2e tests drive shells in a pty and time out in the darwin sandbox
      atuin = prev.atuin.overrideAttrs { doCheck = false; };
    };
}

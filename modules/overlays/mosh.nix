{
  # mosh hardcodes the disconnected-state notification bar to fg 7 on bg 4
  # catppuccin's ansi 4 is a pastel blue, so light text on it is unreadable
  # swap the background to xterm 256-color 17 (dark navy) for contrast
  flake.overlays.mosh = _final: prev: {
    mosh = prev.mosh.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace src/frontend/terminaloverlay.cc \
          --replace-fail "set_background_color( 4 )" "set_background_color( 17 )"
      '';
    });
  };
}

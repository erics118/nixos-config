{
  flake.overlays.glow = _: prev: {
    glow = prev.glow.overrideAttrs (old: {
      # glamour defaults code blocks to terminal256, which shifts every catppuccin color
      postPatch = (old.postPatch or "") + ''
        substituteInPlace main.go --replace-fail \
          'glamour.WithWordWrap(int(width)), //nolint:gosec' \
          'glamour.WithWordWrap(int(width)), //nolint:gosec
        glamour.WithChromaFormatter("terminal16m"),'
        substituteInPlace ui/pager.go --replace-fail \
          'glamour.NewTermRenderer(options...)' \
          'glamour.NewTermRenderer(append(options, glamour.WithChromaFormatter("terminal16m"))...)'
      '';
    });
  };
}

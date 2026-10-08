{
  # continuum skips auto-restore when it sees another tmux process, and it counts
  # servers on other sockets (tmux -L or -S, as agents and tests start) too
  flake.overlays.tmux-continuum = _final: prev: {
    tmuxPlugins = prev.tmuxPlugins // {
      continuum = prev.tmuxPlugins.continuum.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace scripts/helpers.sh \
            --replace-fail '\grep -v "^tmux source"' '\grep -v -e "^tmux source" -e "^tmux -[LS]"'
        '';
      });
    };
  };
}

{
  flake.modules.homeManager.base = { pkgs, repoFileAll, ... }: {
    # every conf here is symlinked into ~/.config/tmux, so it can be reloaded
    # with `tmux source-file` without a rebuild. named main.conf rather than
    # tmux.conf, which home-manager generates itself
    home.file = repoFileAll "modules/eric/cli/tmux" ".config/tmux";

    programs.tmux = {
      enable = true;
      extraConfig = ''
        source-file -q ~/.config/tmux/main.conf
        # plugins load after main.conf, see its resurrect/continuum block
        # resurrect must load before continuum, which depends on it
        # drop scratch-* lines from each save so scratch sessions never restore
        set -g @resurrect-hook-post-save-layout '${pkgs.gnused}/bin/sed -i "/^[a-z_]*\tscratch-/d"'
        run-shell ${pkgs.tmuxPlugins.resurrect.rtp}
        run-shell ${pkgs.tmuxPlugins.continuum.rtp}
      '';
    };
  };
}

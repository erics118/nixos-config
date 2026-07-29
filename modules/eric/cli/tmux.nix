{
  flake.modules.homeManager.base = { pkgs, repoFileAll, ... }: {
    # every conf here is symlinked into ~/.config/tmux, so it can be reloaded
    # with `tmux source-file` without a rebuild. named main.conf rather than
    # tmux.conf, which home-manager generates itself
    home.file = repoFileAll "modules/eric/cli/tmux" ".config/tmux";

    programs.tmux = {
      enable = true;
      # socket under /run instead of /tmp; darwin has no XDG_RUNTIME_DIR so
      # scope to linux, else tmux points at a nonexistent /run/user dir
      secureSocket = pkgs.stdenv.hostPlatform.isLinux;
      extraConfig = ''
        source-file -q ~/.config/tmux/main.conf
      '';
    };
  };
}

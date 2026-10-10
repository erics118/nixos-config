{
  flake.modules.homeManager.base = { config, pkgs, ... }: {
    programs.sesh = {
      enable = true;
      # sesh-pick replaces the module's alias and tmux binding
      enableAlias = false;
      enableTmuxIntegration = false;
      # hidden per-session scratch popups from tmux-popup (see scripts/tmux-popup.sh)
      settings.blacklist = [ "^scratch-" ];
      settings.session = [
        {
          name = "nixos-config";
          path = "~/nixos-config";
        }
      ];
    };

    # one picker for t, tmux-popup, and rtmux on remote hosts
    home.packages = [
      (pkgs.writeShellApplication {
        name = "sesh-pick";
        runtimeInputs = [
          config.programs.sesh.package
          pkgs.fzf
        ];
        text = builtins.readFile ./sesh/sesh-pick.sh;
      })
    ];
  };
}

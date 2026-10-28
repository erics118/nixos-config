{
  flake.modules.homeManager.base = { config, pkgs, ... }: {
    programs.sesh = {
      enable = true;
      # sesh-pick replaces the module's alias and tmux binding
      enableAlias = false;
      enableTmuxIntegration = false;
      settings.session = [
        {
          name = "nixos-config";
          path = "~/nixos-config";
        }
      ];
      # course folders are unique without the latex repo and term prefix
      settings.name_substitution = [
        {
          find = "^~/dev/latex/[^/]+/";
          replace = "";
          regex = true;
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
          pkgs.jq
        ];
        text = builtins.readFile ./sesh/sesh-pick.sh;
      })
    ];
  };
}

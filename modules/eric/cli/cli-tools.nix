{
  flake.modules.homeManager.base = {
    programs.zoxide.enable = true;

    programs.fzf = {
      enable = true;
      defaultOptions = [
        "--preview"
        "'bat --color=always --style=numbers --line-range=:500 {}'"
      ];
    };

    programs.atuin = {
      enable = true;
      forceOverwriteSettings = true;
      flags = [
        "--disable-up-arrow"
      ];
      settings = {
        enter_accept = false;
      };
    };

    programs.eza = {
      enable = true;
      colors = "auto";
      icons = "auto";
      extraOptions = [
        "-F"
      ];
      # disable eza aliases, as we set them up manually
      enableZshIntegration = false;
    };

    programs.tealdeer = {
      enable = true;
      settings = {
        display = {
          compact = false;
          use_pager = false;
          show_title = true;
        };
        updates.auto_update = true;
      };
    };

    programs.jq.enable = true;

    programs.ripgrep.enable = true;

    programs.fd.enable = true;

    programs.bat = {
      enable = true;
      config = {
        style = "changes,header";
        italic-text = "always";
        tabs = "4";
      };
    };

    programs.btop = {
      enable = true;
      settings = {
        vim_keys = true;
        rounded_corners = true;
        theme_background = true;
        truecolor = true;
        # presets = "cpu:1:default,proc:0:default cpu:0:default,mem:0:default,net:0:default cpu:0:block,net:0:tty";
      };
    };
  };
}

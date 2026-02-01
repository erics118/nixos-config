{ ... }:

{
  programs.starship = {
    enable = true;
    settings = fromTOML (builtins.readFile ./starship.toml);
  };

  programs.zoxide = {
    enable = true;
    options = [
      "--cmd"
      ","
    ];
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config = {
      global = {
        load_dotenv = true;
        strict_env = true;
        hide_env_diff = true;
      };
    };
  };

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

  programs.jq = {
    enable = true;
  };

  programs.ripgrep = {
    enable = true;
  };

  programs.fd = {
    enable = true;
  };

  programs.btop = {
    enable = true;
  };

  programs.lazygit = {
    enable = true;
  };

  programs.bat = {
    enable = true;
  };
}

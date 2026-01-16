{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    defaultKeymap = "emacs";
    initContent = ''
      # opt-left
      bindkey "^[[1;3D" backward-word
      # opt-right
      bindkey "^[[1;3C" forward-word
      # ctrl-left
      bindkey "^[[1;5D" beginning-of-line
      # ctrl-right
      bindkey "^[[1;5C" end-of-line
    '';

    localVariables = {
      WORDCHARS = "*?_-.~";

      # zsh abbr
      ABBR_SET_LINE_CURSOR = "1";
      ABBR_SET_EXPANSION_CURSOR = "1";

      ABBR_LINE_CURSOR_MARKER = "{{}}";
      ABBR_EXPANSION_CURSOR_MARKER = "{{}}";

      ABBR_GET_AVAILABLE_ABBREVIATION = "1";
      ABBR_LOG_AVAILABLE_ABBREVIATION = "1";
    };

    autocd = false;

    shellAliases = {
      ls = "eza";

      n = "nvim";
      c = "bat";

      mv = "mv -i";
      cp = "cp -i";
      rm = "rm -i";

      cloc = "tokei";
      sshn = "ssh -o PubkeyAuthentication=no";
    };

    zsh-abbr = {
      enable = true;
      abbreviations = {
        g = "git";
        ga = "git add";
        gb = "git branch";
        gc = "git commit";
        gC = "git commit -v --amend";
        gcb = "git checkout -b";
        gcl = "git clone";
        gcm = "git commit -m \"{{}}\"";
        gco = "git checkout";
        gchp = "git cherry-pick";
        gd = "git diff";
        gl = "git log";
        glg = "git lg";
        gm = "git merge";
        gP = "git pull";
        gp = "git push";
        gpf = "git push -f";
        gs = "git status";
        gr = "git rebase";
        gri = "git rebase -i";

        la = "ls -la";
        lah = "ls -lah";
        lt = "ls --tree";
        tree = "ls --tree";

        lg = "lazygit";
      };
    };
  };

  # Force overwrite zsh-abbr user-abbreviations file
  xdg.configFile."zsh-abbr/user-abbreviations".force = true;

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
    # dizable eza aliases, set up manually
    # this doesnt disable it though?
    enableZshIntegration = false;
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
    # config = {
    #   theme = "Catppuccin Mocha";
    # };
    # themes = {
    #   catppuccin-mocha = {
    #     src = pkgs.fetchFromGitHub {
    #       owner = "catppuccin";
    #       repo = "bat";
    #       rev = "6810349b28055dce54076712fc05fc68da4b8ec0";
    #       sha256 = "sha256-lJapSgRVENTrbmpVyn+UQabC9fpV1G1e+CdlJ090uvg=";
    #     };
    #     file = "Themes/Catppuccin Mocha.tmTheme";
    #   };
    # };
  };
}

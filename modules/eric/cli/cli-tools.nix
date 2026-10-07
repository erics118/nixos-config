{
  flake.modules.homeManager.base = { pkgs, ... }: {
    programs.zoxide = {
      enable = true;
      enableZshIntegration = false; # pre-computed in zsh.nix
    };

    programs.nix-your-shell = {
      enable = true;
      enableZshIntegration = false; # pre-computed in zsh.nix
    };

    programs.fzf = {
      enable = true;
      enableZshIntegration = false; # pre-computed in zsh.nix
      # a script keeps the preview's own quoting out of FZF_DEFAULT_OPTS, which
      # home-manager exports inside unescaped double quotes
      defaultOptions = [
        "--preview='${pkgs.writeShellScript "fzf-preview" ''
          if [ -f "$1" ]; then
            bat --color=always --style=numbers --line-range=:500 -- "$1"
          elif [ -d "$1" ]; then
            eza --tree --color=always --icons=always -- "$1"
          else
            printf '%s\n' "$1"
          fi
        ''} {}'"
      ];
      historyWidget.command = "";
    };

    programs.atuin = {
      enable = true;
      enableZshIntegration = false; # pre-computed in zsh.nix
      forceOverwriteSettings = true;
      settings = {
        enter_accept = true;
        history_filter = [ "^\\?" ];
        filter_mode_shell_up_key_binding = "session";
        prefers_reduced_motion = true;
        records = true;
        stats = {
          common_subcommands = [
            "apt"
            "cargo"
            "docker"
            "git"
            "go"
            "kubectl"
            "nix"
            "npm"
            "pnpm"
            "podman"
            "port"
            "systemctl"
            "tmux"
            "yarn"
            "dune"
            "just"
            "npx"
          ];
          common_prefix = [ "sudo" ];
          command_aliases = {
            "dune te" = "dune runtest";
            "dune test" = "dune runtest";
            "dune b" = "dune build";
            "k" = "killall";
            "sshn" = "ssh";
            "npm i" = "npm install";
            "cargo b" = "cargo build";
          };
        };
      };
    };

    programs.eza = {
      enable = true;
      # these generate the `eza` alias, and zsh.nix points ls at it
      colors = "auto";
      icons = "auto";
      extraOptions = [
        "-F"
        "auto"
      ];
      # disable the ls/ll/la aliases, as ls is set up manually
      enableZshIntegration = false;
    };

    # build/project files only bold and yellow
    home.sessionVariables.EZA_COLORS = "bu=1;33";

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
      # cudaSupport only runs autoAddDriverRunpath so btop finds libnvidia-ml at
      # runtime for the gpu panel, it pulls in no cuda toolkit and stays cached
      package = pkgs.btop.override { cudaSupport = true; };
      settings = {
        vim_keys = true;
        rounded_corners = true;
        theme_background = true;
        truecolor = true;
      };
    };
  };
}

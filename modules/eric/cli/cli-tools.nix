{
  flake.modules.homeManager.base = {
    programs.zoxide = {
      enable = true;
      enableZshIntegration = false; # pre-computed in shell.nix
    };

    programs.nix-your-shell = {
      enable = true;
      enableZshIntegration = false; # pre-computed in shell.nix
    };

    programs.fzf = {
      enable = true;
      defaultOptions = [
        "--preview='if [ -f {} ]; then bat --color=always --style=numbers --line-range=:500 -- {}; elif [ -d {} ]; then eza --tree --color=always --icons=always -- {}; else printf \"%s\\n\" {}; fi'"
      ];
    };

    programs.atuin = {
      enable = true;
      forceOverwriteSettings = true;
      settings = {
        enter_accept = true;
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
      colors = "auto";
      icons = "auto";
      extraOptions = [ "-F" ];
      # disable eza aliases, as we set them up manually
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

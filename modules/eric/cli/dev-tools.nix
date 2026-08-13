{
  flake.modules.homeManager.base = { lib, pkgs, ... }: {
    programs.direnv = {
      enable = true;
      enableZshIntegration = false; # pre-computed in shell.nix
      nix-direnv.enable = true;
      config = {
        global = {
          load_dotenv = true;
          strict_env = true;
          hide_env_diff = true;
        };
      };
    };

    programs.lazygit = {
      enable = true;

      settings = {
        gui = {
          nerdFontsVersion = "3";
          filterMode = "fuzzy";
          showRandomTip = false;
        };
        git.pagers = [
          {
            colorArg = "always";
            pager = "delta --paging=never";
          }
        ];
        update.method = "never";
      };
    };

    # on darwin, lazygit follows XDG_CONFIG_HOME at runtime, but home-manager writes to
    # Application Support at build time; manually build the symlink to XDG_CONFIG_HOME
    home.activation.lazygitXdgConfig = lib.mkIf pkgs.stdenv.isDarwin (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "$HOME/.config/lazygit"
        ln -sf "$HOME/Library/Application Support/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
      ''
    );
  };
}

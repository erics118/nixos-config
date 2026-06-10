{
  flake.modules.homeManager.base = { lib, ... }: {
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
        };
        update.method = "never";
      };
    };

    # lazygit follows XDG_CONFIG_HOME at runtime, but home-manager's macOS module
    # writes to Application Support at build time; symlink to bridge the two
    home.activation.lazygitXdgConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/.config/lazygit"
      ln -sf "$HOME/Library/Application Support/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
    '';
  };
}

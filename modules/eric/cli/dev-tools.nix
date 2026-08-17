{
  flake.modules.homeManager.base = {
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
        git.diffRenderers = [
          {
            colorArg = "always";
            command = "delta --paging=never";
          }
        ];
        update.method = "never";
      };
    };
  };
}

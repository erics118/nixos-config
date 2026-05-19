{
  flake.modules.homeManager.base = {
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

    programs.lazygit.enable = true;
  };
}

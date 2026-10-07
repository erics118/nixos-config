{
  flake.modules.homeManager.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      programs.direnv = {
        enable = true;
        enableZshIntegration = false; # pre-computed in zsh.nix
        nix-direnv.enable = true;
        # nix pins bash, direnv, and nix-direnv together, so its per-load version check can't fail
        # unexported, so it stays out of the environment direnv hands to the shell
        stdlib = "NIX_DIRENV_SKIP_VERSION_CHECK=1";
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
        # its lg cd-on-exit wrapper never runs, since the lg abbr expands to lazygit first
        enableZshIntegration = false;

        settings = {
          gui = {
            nerdFontsVersion = "3";
            filterMode = "fuzzy";
            showRandomTip = false;
            showNumstatInFilesView = true;
          };
          git = {
            autoFetch = false;
            overrideGpg = true;
            diffRenderers = [
              {
                colorArg = "always";
                command = "delta --paging=never";
              }
            ];
          };
          update.method = "never";
          disableStartupPopups = true;
          promptToReturnFromSubprocess = false;
        };
      };

      # lazygit on macOS reads ~/Library/Application Support/lazygit/config.yml, but home-manager writes to ~/.config/lazygit/config.yml
      home.file."Library/Application Support/lazygit/config.yml" =
        lib.mkIf pkgs.stdenv.hostPlatform.isDarwin
          { inherit (config.home.file."${config.xdg.configHome}/lazygit/config.yml") source enable; };

      xdg.configFile."clangd/config.yaml".text = ''
        InlayHints:
          Enabled: true
          ParameterNames: true
          DeducedTypes: true

        Hover:
          ShowAKA: true
      '';

      # clangd on macOS reads ~/Library/Preferences/clangd/config.yaml, not ~/.config
      home.file."Library/Preferences/clangd/config.yaml" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        inherit (config.home.file."${config.xdg.configHome}/clangd/config.yaml") source enable;
      };
    };
}

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

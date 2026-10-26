{
  flake.modules =
    let
      # ntfy cli default host + token, so `ntfy pub/sub <topic>` needs no flags
      client = { config, pkgs, ... }: {
        environment.systemPackages = [ pkgs.ntfy-sh ];

        sops.templates."ntfy-client.yml" = {
          content = ''
            default-host: https://${config.ntfyHost}
            default-token: ${config.sops.placeholder."ntfy/token"}
          '';
          owner = "eric";
          mode = "0600";
        };

        # a template path under home would make sops-nix create ~/.config as root on a fresh install
        home-manager.users.eric = hm: {
          xdg.configFile."ntfy/client.yml".source =
            hm.config.lib.file.mkOutOfStoreSymlink
              config.sops.templates."ntfy-client.yml".path;
        };
      };
    in
    {
      nixos.ntfy-client = client;
      darwin.ntfy-client = client;

      # macos ntfy cli reads ~/Library/Application Support/ntfy/client.yml,
      # so point it at the .config file the sops template renders
      homeManager.darwin = { config, ... }: {
        home.file."Library/Application Support/ntfy/client.yml".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/ntfy/client.yml";
      };
    };
}

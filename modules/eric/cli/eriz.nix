{
  flake.modules =
    let
      # eriz.sh is vendored from the private eriz-links repo, which the deploy
      # keys cannot fetch as a flake input
      client = { config, pkgs, ... }: {
        environment.systemPackages = [
          (pkgs.writeShellApplication {
            name = "eriz";
            runtimeInputs = with pkgs; [
              curl
              jq
            ];
            text = builtins.readFile ./eriz/eriz.sh;
          })
        ];

        # sourced by eriz.sh
        sops.templates."eriz-credentials" = {
          content = ''
            CF_ACCESS_CLIENT_ID='${config.sops.placeholder."eriz/client_id"}'
            CF_ACCESS_CLIENT_SECRET='${config.sops.placeholder."eriz/client_secret"}'
          '';
          owner = "eric";
          mode = "0600";
        };

        # a template path under home would make sops-nix create ~/.config as root on a fresh install
        home-manager.users.eric = hm: {
          xdg.configFile."eriz/credentials".source =
            hm.config.lib.file.mkOutOfStoreSymlink
              config.sops.templates."eriz-credentials".path;
        };
      };
    in
    {
      nixos.eriz = client;
      darwin.eriz = client;
    };
}

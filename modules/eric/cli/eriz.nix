{
  flake.modules =
    let
      # eriz.sh is vendored from the private eriz-links repo, which the deploy
      # keys cannot fetch as a flake input
      client = home: { config, pkgs, ... }: {
        environment.systemPackages = [
          (pkgs.writeShellApplication {
            name = "eriz";
            runtimeInputs = with pkgs; [
              curl
              jq
            ];
            text = builtins.readFile ./eriz/eriz.sh;
            # the credentials path is only known at runtime
            excludeShellChecks = [ "SC1090" ];
          })
        ];

        # sourced by eriz.sh
        sops.templates."eriz-credentials" = {
          content = ''
            CF_ACCESS_CLIENT_ID='${config.sops.placeholder."eriz/client_id"}'
            CF_ACCESS_CLIENT_SECRET='${config.sops.placeholder."eriz/client_secret"}'
          '';
          path = "${home}/.config/eriz/credentials";
          owner = "eric";
          mode = "0600";
        };
      };
    in
    {
      nixos.eriz = client "/home/eric";
      darwin.eriz = client "/Users/eric";
    };
}

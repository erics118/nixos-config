{
  flake.modules =
    let
      # ntfy cli default host + token, so `ntfy pub/sub <topic>` needs no flags
      client = home: { config, pkgs, ... }: {
        environment.systemPackages = [ pkgs.ntfy-sh ];

        sops.templates."ntfy-client.yml" = {
          content = ''
            default-host: https://ntfy.eriz.cc
            default-token: ${config.sops.placeholder."ntfy/token"}
          '';
          path = "${home}/.config/ntfy/client.yml";
          owner = "eric";
          mode = "0600";
        };
      };
    in
    {
      nixos.ntfy-client = client "/home/eric";
      darwin.ntfy-client = client "/Users/eric";
    };
}

{
  flake.modules.nixos.scrutiny = { config, lib, ... }: {
    services.scrutiny = {
      enable = true;

      # database for time series history
      influxdb.enable = true;

      collector = {
        enable = true;
        # sample every 6 hours
        schedule = "00/6:00";
      };

      settings.web.listen.port = 8083;
    };

    services.caddy.virtualHosts."scrutiny.h.eriz.cc" = lib.mkIf config.services.caddy.enable {
      extraConfig = ''
        reverse_proxy localhost:8083
      '';
    };

    homepageTiles = lib.mkIf config.services.homepage-dashboard.enable [
      {
        name = "Scrutiny";
        group = "Infrastructure";
        port = 8083;
        subdomain = "scrutiny";
        description = "Disk SMART health";
        icon = "scrutiny.svg";
      }
    ];
  };
}

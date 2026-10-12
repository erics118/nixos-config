{
  flake.modules.nixos.scrutiny =
    { config, ... }:
    let
      port = 8083;
    in
    {
      # inject the ntfy token into the notify url
      sops.templates."scrutiny-notify-url" = {
        content = "ntfy://:${config.sops.placeholder."ntfy/token"}@${config.ntfyHost}/scrutiny";
        restartUnits = [ "scrutiny.service" ];
      };

      # scrutiny uses DynamicUser, so systemd hands it a private copy of the root-only file
      systemd.services.scrutiny.serviceConfig.LoadCredential = "notify:${
        config.sops.templates."scrutiny-notify-url".path
      }";

      # influxdb holds scrutiny's default admin login, so keep it local
      services.influxdb2.settings.http-bind-address = "127.0.0.1:8086";

      services.scrutiny = {
        enable = true;

        # database for time series history
        influxdb.enable = true;

        settings.web.listen.port = port;
        settings.web.influxdb.host = "127.0.0.1";

        collector = {
          enable = true;
          # sample every 6 hours
          schedule = "00/6:00";
        };

        settings.notify.urls = [ { _secret = "/run/credentials/scrutiny.service/notify"; } ];
      };

      homepageTiles = [
        {
          name = "Scrutiny";
          group = "Infrastructure";
          inherit port;
          subdomain = "scrutiny";
          description = "Disk SMART health";
          icon = "scrutiny.svg";
          widget = {
            type = "scrutiny";
          };
        }
      ];
    };
}

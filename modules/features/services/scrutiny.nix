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
        # scrutiny uses DynamicUser, so it can't own the file; make it readable
        mode = "0444";
      };

      services.scrutiny = {
        enable = true;

        # database for time series history
        influxdb.enable = true;

        settings.web.listen.port = port;

        collector = {
          enable = true;
          # sample every 6 hours
          schedule = "00/6:00";
        };

        settings.notify.urls = [ { _secret = config.sops.templates."scrutiny-notify-url".path; } ];
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

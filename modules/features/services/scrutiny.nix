{
  flake.modules.nixos.scrutiny = { config, lib, ... }: {
    # build the notif url from the topic at runtime
    sops.templates."scrutiny-notify-url" = {
      content = "ntfy://ntfy.sh/${config.sops.placeholder."ntfy/general"}";
      # scrutiny uses DynamicUser, so it can't own the file; make it readable
      mode = "0444";
    };

    services.scrutiny = {
      enable = true;

      # database for time series history
      influxdb.enable = true;

      settings.web.listen.port = 8083;

      collector = {
        enable = true;
        # sample every 6 hours
        schedule = "00/6:00";
      };

      settings.notify.urls = [ { _secret = config.sops.templates."scrutiny-notify-url".path; } ];
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

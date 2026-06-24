{
  flake.modules.nixos.gatus = { config, lib, ... }: {
    # inject ntfy topic at runtime
    sops.templates."gatus-env".content = ''
      NTFY_TOPIC=${config.sops.placeholder."ntfy/gatus"}
    '';

    services.gatus = {
      enable = true;
      environmentFile = config.sops.templates."gatus-env".path;

      settings = {
        web.port = 8084;

        alerting.ntfy = {
          url = "https://ntfy.sh";
          topic = "\${NTFY_TOPIC}";
          priority = 3;
          "default-alert" = {
            "failure-threshold" = 3;
            "success-threshold" = 2;
            "send-on-resolved" = true;
          };
        };

        # generate from homepageTiles
        # use tcp to avoid issues from redirects
        endpoints = map (t: {
          inherit (t) name;
          inherit (t) group;
          url = "tcp://${t.host}:${toString t.port}";
          interval = "1m";
          conditions = [ "[CONNECTED] == true" ];
          alerts = [ { type = "ntfy"; } ];
        }) config.homepageTiles;
      };
    };

    homepageTiles = lib.mkIf config.services.homepage-dashboard.enable [
      {
        name = "Gatus";
        group = "Infrastructure";
        port = 8084;
        subdomain = "gatus";
        description = "Service uptime";
        icon = "gatus.svg";
      }
    ];
  };
}

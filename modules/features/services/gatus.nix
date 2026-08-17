{
  flake.modules.nixos.gatus =
    { config, ... }:
    let
      port = 8084;
    in
    {
      # inject ntfy token at runtime
      sops.templates."gatus-env".content = ''
        NTFY_TOKEN=${config.sops.placeholder."ntfy/token"}
      '';

      services.gatus = {
        enable = true;
        environmentFile = config.sops.templates."gatus-env".path;

        settings = {
          web.port = port;

          storage = {
            type = "sqlite";
            path = "/var/lib/gatus/gatus.db";
          };

          alerting.ntfy = {
            url = "https://${config.ntfyHost}";
            topic = "gatus";
            token = "\${NTFY_TOKEN}";
            priority = 3;
            "default-alert" = {
              "failure-threshold" = 3;
              "success-threshold" = 2;
              "send-on-resolved" = true;
            };
          };

          # generate from homepageTiles, skipping port-less ones (external/href tiles)
          # use tcp to avoid issues from redirects
          endpoints = map (t: {
            inherit (t) name;
            inherit (t) group;
            url = "tcp://${t.host}:${toString t.port}";
            interval = "1m";
            conditions = [ "[CONNECTED] == true" ];
            alerts = [ { type = "ntfy"; } ];
          }) (builtins.filter (t: t.port != null) config.homepageTiles);
        };
      };

      homepageTiles = [
        {
          name = "Gatus";
          group = "Infrastructure";
          inherit port;
          subdomain = "gatus";
          description = "Service uptime";
          icon = "gatus.svg";
          widget = {
            type = "gatus";
          };
        }
      ];
    };
}

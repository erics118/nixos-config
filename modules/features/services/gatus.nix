{
  flake.modules.nixos.gatus =
    { config, ... }:
    let
      port = 8084;
    in
    {
      # inject ntfy token at runtime
      sops.templates."gatus-env" = {
        content = ''
          NTFY_TOKEN=${config.sops.placeholder."ntfy/token"}
        '';
        restartUnits = [ "gatus.service" ];
      };

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
          endpoints =
            map (t: {
              inherit (t) name;
              inherit (t) group;
              url = "tcp://${t.host}:${toString t.port}";
              interval = "1m";
              conditions = [ "[CONNECTED] == true" ];
              alerts = [ { type = "ntfy"; } ];
            }) (builtins.filter (t: t.port != null) config.homepageTiles)
            ++ [
              {
                name = "eriz.cc";
                group = "Websites";
                url = "https://eriz.cc";
                interval = "1m";
                # root 302s to ericzshen.com; check the worker's own response, not the redirect target
                client."ignore-redirect" = true;
                conditions = [ "[STATUS] == 302" ];
                alerts = [ { type = "ntfy"; } ];
              }
              {
                name = "ericzshen.com";
                group = "Websites";
                url = "https://ericzshen.com";
                interval = "1m";
                conditions = [ "[STATUS] == 200" ];
                alerts = [ { type = "ntfy"; } ];
              }
            ]
            ++ [
              {
                name = "TLS certificate";
                group = "Infrastructure";
                url = "https://${config.homelabDomain}";
                interval = "1h";
                # caddy renews at about 30 days left, so under 7 means renewal has been failing for weeks
                conditions = [ "[CERTIFICATE_EXPIRATION] > 168h" ];
                alerts = [ { type = "ntfy"; } ];
              }
            ];
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

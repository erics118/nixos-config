{
  # homepageTiles and homelabDomain are declared in base, see homelab-options.nix
  flake.modules.nixos.homepage = { config, lib, ... }: {
    config =
      let
        inherit (config) homelabDomain;
        port = 8082;
        mkUrl = host: p: "http://${host}:${toString p}";
        tileToService = t: {
          ${t.name} = lib.filterAttrs (_: v: v != null) {
            href = if t.href != null then t.href else "https://${t.subdomain}.${homelabDomain}";
            siteMonitor = if t.href != null then t.href else mkUrl t.host t.port;
            inherit (t) description;
            inherit (t) icon;
            widget = if t.widget != null then ({ url = mkUrl t.host t.port; } // t.widget) else null;
          };
        };
        grouped = lib.groupBy (t: t.group) config.homepageTiles;
        services = lib.mapAttrsToList (group: tiles: { ${group} = map tileToService tiles; }) grouped;
      in
      {
        services.homepage-dashboard = {
          enable = true;

          openFirewall = true;

          listenPort = port;

          # tailscale is reached by its magicdns name, not its address, which can change
          allowedHosts = lib.concatStringsSep "," [
            "localhost:${toString port}"
            "127.0.0.1:${toString port}"
            "${config.networking.hostName}:${toString port}"
            "192.168.68.150:${toString port}"
            "narwhal.dolphin-sailfin.ts.net:${toString port}"
            homelabDomain
          ];

          settings = {
            title = config.networking.hostName;
            headerStyle = "clean";
            # each group spans a full-width row; tiles wrap every 3 columns
            layout = lib.mapAttrs (_group: _tiles: {
              style = "row";
              columns = 3;
            }) grouped;
          };

          inherit services;

          widgets = [
            {
              glances = {
                url = "http://narwhal.dolphin-sailfin.ts.net:61208";
                cpu = true;
                mem = true;
                cputemp = true;
                uptime = true;
                disk = [
                  "/"
                  "/mnt/external"
                ];
                expanded = true;
                version = 4;
                label = "narwhal";
              };
            }
            {
              glances = {
                url = "http://turtle.dolphin-sailfin.ts.net:61208";
                cpu = true;
                mem = true;
                uptime = true;
                disk = "/";
                expanded = true;
                version = 4;
                label = "turtle";
              };
            }
          ];
        };

        # the dashboard is the home root
        # services live at <service>.<homelabDomain>
        # proxied to host:port from the registry
        services.caddy.virtualHosts = lib.mkMerge (
          [ { ${homelabDomain}.extraConfig = "reverse_proxy localhost:${toString port}"; } ]
          ++ map (t: {
            "${t.subdomain}.${homelabDomain}".extraConfig = "reverse_proxy ${t.host}:${toString t.port}";
          }) (lib.filter (t: t.proxy) config.homepageTiles)
        );
      };
  };
}

{
  flake.modules.nixos.homepage = { config, lib, ... }: {
    # each module appends to homepageTiles with a flat structure
    options.homepageTiles = lib.mkOption {
      default = [ ];
      description = "Flat list of service tiles, merged from all modules and transformed here";
      type = lib.types.listOf (
        lib.types.submodule (
          { config, ... }: {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = "Unique name for the tile";
              };
              group = lib.mkOption {
                type = lib.types.str;
                description = "Dashboard group the tile is listed under";
              };
              subdomain = lib.mkOption {
                type = lib.types.str;
                default = lib.toLower config.name;
                description = "Link target, defaults to name; expands to https://<subdomain>.h.eriz.cc";
              };
              port = lib.mkOption {
                type = lib.types.port;
                description = "Service port, used for the uptime monitor and widget";
              };
              host = lib.mkOption {
                type = lib.types.str;
                default = "127.0.0.1";
                description = "IP used for the uptime monitor and widget; defaults to localhost";
              };
              proxy = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Generate a Caddy reverse-proxy vhost <subdomain>.h.eriz.cc";
              };
              description = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Short caption shown under the tile name";
              };
              icon = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Icon file name, e.g. adguard.svg";
              };
              widget = lib.mkOption {
                type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
                default = null;
                description = "Homepage widget config; the service url is filled in automatically";
              };
            };
          }
        )
      );
    };

    config =
      let
        mkUrl = host: port: "http://${host}:${toString port}";
        tileToService = t: {
          ${t.name} = lib.filterAttrs (_: v: v != null) {
            href = "https://${t.subdomain}.h.eriz.cc";
            siteMonitor = mkUrl t.host t.port;
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

          listenPort = 8082;

          allowedHosts = lib.concatStringsSep "," [
            "localhost:8082"
            "127.0.0.1:8082"
            "narwhal:8082"
            "192.168.68.150:8082"
            "100.122.182.28:8082"
            "narwhal.dolphin-sailfin.ts.net:8082"
            "h.eriz.cc"
          ];

          settings = {
            title = "narwhal";
            headerStyle = "clean";
            # each group spans a full-width row; tiles wrap every 4 columns
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
                version = 4;
                label = "turtle";
              };
            }
          ];
        };

        # the dashboard is the home root
        # services live at <service>.h.eriz.cc
        # proxied to host:port from the registry
        services.caddy.virtualHosts = lib.mkMerge (
          [ { "h.eriz.cc".extraConfig = "reverse_proxy localhost:8082"; } ]
          ++ map (t: {
            "${t.subdomain}.h.eriz.cc".extraConfig = "reverse_proxy ${t.host}:${toString t.port}";
          }) (lib.filter (t: t.proxy) config.homepageTiles)
        );
      };
  };
}

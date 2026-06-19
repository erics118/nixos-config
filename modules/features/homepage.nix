{
  flake.modules.nixos.homepage = { config, lib, ... }: {
    # each module appends to homepageTiles with a flat structure
    options.homepageTiles = lib.mkOption {
      default = [ ];
      description = "Flat list of service tiles, merged from all modules and transformed here";
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption { type = lib.types.str; };
            group = lib.mkOption { type = lib.types.str; };
            port = lib.mkOption { type = lib.types.port; };
            # host used in the href url, defaults to narwhal's tailscale hostname
            host = lib.mkOption {
              type = lib.types.str;
              default = "narwhal.dolphin-sailfin.ts.net";
            };
            # ip used for siteMonitor, defaults to localhost; override for remote services
            ip = lib.mkOption {
              type = lib.types.str;
              default = "127.0.0.1";
            };
            description = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
            icon = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
            widget = lib.mkOption {
              type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
              default = null;
            };
          };
        }
      );
    };

    config =
      let
        makeUrl = host: port: "http://${host}:${toString port}";
        grouped = lib.groupBy (t: t.group) config.homepageTiles;
        services = lib.mapAttrsToList (group: tiles: {
          ${group} = map (t: {
            ${t.name} = lib.filterAttrs (_: v: v != null) {
              href = makeUrl t.host t.port;
              siteMonitor = makeUrl t.ip t.port;
              inherit (t) description;
              inherit (t) icon;
              widget = if t.widget != null then ({ url = makeUrl t.ip t.port; } // t.widget) else null;
            };
          }) tiles;
        }) grouped;
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
          ];

          settings = {
            title = "narwhal";
            headerStyle = "clean";
          };

          inherit services;

          widgets = [
            {
              resources = {
                cpu = true;
                memory = true;
                cputemp = true;
                uptime = true;
                network = true;
                expanded = true;
                refresh = 3000;
                units = "imperial";
                disk = [
                  "/"
                  "/mnt/external"
                ];
              };
            }
          ];
        };
      };
  };
}

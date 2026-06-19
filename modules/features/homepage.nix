{
  flake.modules.nixos.homepage = { config, lib, ... }: {

    # option to make merging tiles easy
    options.homepageTiles = lib.mkOption {
      type = with lib.types; listOf attrs;
      default = [ ];
      description = "Homepage service groups, merged from all modules";
    };

    config = {
      services.homepage-dashboard = {
        enable = true;
        openFirewall = true;

        listenPort = 8082;

        # allow narwhal to be reached over LAN and tailscale
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

        # merged tiles
        services = config.homepageTiles;

        # system resource widgets
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

      homepageTiles = [
        {
          "Infrastructure" = [
            {
              "AdGuard Home" = {
                href = "http://narwhal.dolphin-sailfin.ts.net:3000";
                siteMonitor = "http://127.0.0.1:3000";
                description = "DNS & ad blocking";
                icon = "adguard-home.svg";
              };
            }
          ];
        }
      ];
    };
  };
}

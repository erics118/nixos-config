{
  flake.modules.nixos.adguardhome =
    _:
    let
      port = 3000;
    in
    {
      services.adguardhome = {
        enable = true;

        # mutable so the UI can manage blocklists/clients/stats
        mutableSettings = true;

        settings = {
          # web UI on :3000
          http.address = "0.0.0.0:${toString port}";

          dns = {
            # cloudflare DoH as primary, quad9 as fallback
            # no IPv6, as the router narwhal uses doesn't support it
            upstream_dns = [
              "https://1.1.1.1/dns-query"
              "https://1.0.0.1/dns-query"
            ];
            fallback_dns = [
              "9.9.9.9"
              "149.112.112.112"
            ];
          };

          # declaring filters here makes Nix own the blocklist set
          filters = [
            {
              enabled = true;
              id = 1;
              name = "AdGuard DNS filter";
              url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
            }
            {
              enabled = true;
              id = 2;
              name = "AdAway Default Blocklist";
              url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt";
            }
            {
              enabled = true;
              id = 5;
              name = "OISD Blocklist Small";
              url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_5.txt";
            }
            {
              enabled = true;
              id = 11;
              name = "Malicious URL Blocklist (URLHaus)";
              url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_11.txt";
            }
            {
              enabled = true;
              id = 30;
              name = "Phishing URL Blocklist (PhishTank and OpenPhish)";
              url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_30.txt";
            }
          ];
        };
      };

      networking.firewall = {
        allowedTCPPorts = [
          53
          port
        ];
        allowedUDPPorts = [ 53 ];
      };

      homepageTiles = [
        {
          name = "AdGuard Home";
          group = "Infrastructure";
          inherit port;
          subdomain = "adguard";
          description = "DNS & ad blocking";
          icon = "adguard-home.svg";
          widget = {
            type = "adguard";
            username = "{{HOMEPAGE_VAR_ADGUARD_USERNAME}}";
            password = "{{HOMEPAGE_VAR_ADGUARD_PASSWORD}}";
          };
        }
      ];
    };
}

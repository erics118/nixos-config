{
  # declared in base rather than in homepage.nix so a host can import any tile
  # producer (adguardhome, gatus, scrutiny, immich, media) without also importing
  # homepage, and so caddy and homepage agree on one domain
  flake.modules.nixos.base = { lib, ... }: {
    options.homelabDomain = lib.mkOption {
      type = lib.types.str;
      default = "h.eriz.cc";
      description = "Base domain for homelab services, served by the caddy wildcard vhost";
    };

    options.ntfyHost = lib.mkOption {
      type = lib.types.str;
      default = "ntfy.eriz.cc";
      description = "Host of the self-hosted ntfy server, used by publishers and the cli";
    };

    # each module appends to homepageTiles with a flat structure
    options.homepageTiles = lib.mkOption {
      default = [ ];
      description = "Flat list of service tiles, merged from all modules and transformed by homepage.nix";
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
                description = "Link target, defaults to name; expands to https://<subdomain>.<homelabDomain>";
              };
              port = lib.mkOption {
                type = lib.types.nullOr lib.types.port;
                default = null;
                description = "Service port, used for the uptime monitor and widget";
              };
              href = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Override the link and uptime monitor with an explicit URL, for services not under homelabDomain";
              };
              host = lib.mkOption {
                type = lib.types.str;
                default = "127.0.0.1";
                description = "IP used for the uptime monitor and widget; defaults to localhost";
              };
              proxy = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Generate a Caddy reverse-proxy vhost <subdomain>.<homelabDomain>";
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
  };
}

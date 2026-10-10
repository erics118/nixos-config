{
  # storage on /mnt/external/immich
  # the module only chowns it to immich:immich 0700 once it exists (tmpfiles
  # `e`); it never creates it, and immich can't (parent mount is eric:users
  # 0755), so we create it declaratively with the tmpfiles rule below
  flake.modules.nixos.immich = { config, ... }: {
    services.immich = {
      enable = true;
      # caddy, gatus and the homepage widget reach it via the tile host
      host = "127.0.0.1";
      mediaLocation = "/mnt/external/immich";
      settings = null; # configure via web ui
    };

    systemd.tmpfiles.rules = [ "d /mnt/external/immich 0700 immich immich -" ];

    # /mnt/external is nofail, so without the disk uploads would land on the root fs
    systemd.services.immich-server.unitConfig.RequiresMountsFor = [ "/mnt/external" ];

    homepageTiles = [
      {
        name = "Immich";
        group = "Apps";
        inherit (config.services.immich) port;
        subdomain = "immich";
        description = "Photo backup";
        icon = "immich.svg";
        widget = {
          type = "immich";
          key = "{{HOMEPAGE_VAR_IMMICH_KEY}}";
          version = 2;
          fields = [
            "photos"
            "videos"
            "storage"
            "users"
          ];
        };
      }
    ];
  };
}

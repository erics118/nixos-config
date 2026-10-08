{
  # storage on /mnt/external/immich
  # the module only chowns it to immich:immich 0700 once it exists (tmpfiles
  # `e`); it never creates it, and immich can't (parent mount is eric:users
  # 0755), so we create it declaratively with the tmpfiles rule below
  flake.modules.nixos.immich = { config, ... }: {
    services.immich = {
      enable = true;
      openFirewall = true;
      mediaLocation = "/mnt/external/immich";
      settings = null; # configure via web ui
    };

    systemd.tmpfiles.rules = [ "d /mnt/external/immich 0700 immich immich -" ];

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

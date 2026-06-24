{
  # storage on /mnt/external/immich
  # the module only chowns it to immich:immich 0700 once it exists (tmpfiles
  # `e`); it never creates it, and immich can't (parent mount is eric:users
  # 0755), so we create it declaratively with the tmpfiles rule below
  flake.modules.nixos.immich = { config, lib, ... }: {
    services.immich = {
      enable = true;
      openFirewall = true;
      mediaLocation = "/mnt/external/immich";
      settings = null; # configure via web ui
    };

    systemd.tmpfiles.rules = [ "d /mnt/external/immich 0700 immich immich -" ];

    services.caddy.virtualHosts."immich.h.eriz.cc" = lib.mkIf config.services.caddy.enable {
      extraConfig = ''
        reverse_proxy localhost:2283
      '';
    };

    homepageTiles = lib.mkIf config.services.homepage-dashboard.enable [
      {
        name = "Immich";
        group = "Apps";
        port = 2283;
        subdomain = "immich";
        description = "Photo backup";
        icon = "immich.svg";
      }
    ];
  };
}

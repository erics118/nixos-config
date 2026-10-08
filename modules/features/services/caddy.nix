{
  flake.modules.nixos.caddy = { pkgs, config, ... }: {
    sops.secrets."api/cloudflare" = {
      owner = "caddy";
    };

    # sops-nix template interpolates the raw token into an EnvironmentFile
    sops.templates."caddy-env" = {
      content = ''
        CF_API_TOKEN=${config.sops.placeholder."api/cloudflare"}
      '';
      owner = "caddy";
    };

    services.caddy = {
      enable = true;

      # caddy with cloudflare DNS provider plugin for DNS-01 ACME challenges
      # on a plugin bump, set hash = lib.fakeHash and copy the hash the build reports
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
        hash = "sha256-xRJ5evsAJ2akg47j3Bt6YDXJOgX88B/rKNP50KSVyNY=";
      };

      globalConfig = ''
        acme_dns cloudflare {env.CF_API_TOKEN}
      '';

      # catch all for unmatched subdomains instead of a TLS error
      # explicit vhosts still take precedence
      virtualHosts."*.${config.homelabDomain}".extraConfig = ''
        respond "no such service" 404
      '';
    };

    systemd.services.caddy.serviceConfig.EnvironmentFile = config.sops.templates."caddy-env".path;
  };
}

{
  flake.modules.nixos.caddy = { pkgs, config, ... }: {
    sops.secrets."api/cloudflare" = { };

    # sops-nix template interpolates the raw token into an EnvironmentFile
    sops.templates."caddy-env" = {
      content = ''
        CF_API_TOKEN=${config.sops.placeholder."api/cloudflare"}
      '';
      restartUnits = [ "caddy.service" ];
    };

    services.caddy = {
      enable = true;

      # caddy with cloudflare DNS provider plugin for DNS-01 ACME challenges
      # on a caddy or plugin bump, set hash = lib.fakeHash and copy the hash the build reports
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
        hash = "sha256-5a5cpFl90pEWt0lUC4ZJQ7g+1//ZvsRhee64Dt9vh5o=";
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

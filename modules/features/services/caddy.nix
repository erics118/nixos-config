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
      # we need to manually specify the plugin and hash
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
        hash = "sha256-8yZDrejNKsaUnUaTUFYbarWNmxafqp2z2rWo+XRsxV8=";
      };

      globalConfig = ''
        acme_dns cloudflare {env.CF_API_TOKEN}
      '';

      # catch all for unmatched subdomains instead of a TLS error
      # explicit vhosts still take precedence
      virtualHosts."*.h.eriz.cc".extraConfig = ''
        respond "no such service" 404
      '';
    };

    systemd.services.caddy.serviceConfig.EnvironmentFile = config.sops.templates."caddy-env".path;
  };
}

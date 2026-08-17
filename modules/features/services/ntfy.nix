{
  flake.modules.nixos.ntfy = { config, ... }: {
    # NTFY_AUTH_USERS + NTFY_AUTH_TOKENS, read by systemd as root before the
    # service drops to its DynamicUser
    sops.secrets."ntfy/auth-env" = { };

    services.ntfy-sh = {
      enable = true;
      environmentFile = config.sops.secrets."ntfy/auth-env".path;
      settings = {
        # public url, fronted by the cloudflare tunnel; listens on 127.0.0.1:2586
        base-url = "https://ntfy.eriz.cc";
        behind-proxy = true;
        auth-default-access = "deny-all";
        enable-signup = false;
        enable-login = true;
        # forwards a poll-request to ntfy.sh so ios can wake on push
        upstream-base-url = "https://ntfy.sh";
      };
    };
  };
}

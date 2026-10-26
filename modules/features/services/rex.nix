{ inputs, ... }: {
  flake.modules.nixos.rex = {
    imports = [ inputs.rex.nixosModules.default ];

    # rex for mac reaches this host at https://<host>.<tailnet>.ts.net, on serve's default port 7297
    services.rex.loginServer = {
      enable = true;
      # only eric's own tailscale login, so people on tailnets the host is shared into get no account
      accounts.eric.principals = [ "tailscale:ericshen118@gmail.com" ];
      tailscaleServe.enable = true;
    };
  };
}

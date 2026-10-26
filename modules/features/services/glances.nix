{
  flake.modules.nixos.glances = {
    services.glances.enable = true;

    # the web ui has no auth and shows process command lines, so only localhost and the tailnet may connect
    systemd.services.glances.serviceConfig = {
      IPAddressDeny = "any";
      IPAddressAllow = [
        "localhost"
        "100.64.0.0/10"
        "fd7a:115c:a1e0::/48"
      ];
    };
  };
}

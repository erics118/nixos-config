{
  flake.modules.nixos.adguardhome = {
    services.adguardhome = {
      enable = true;
      openFirewall = true;
      mutableSettings = true;
    };

    networking.firewall = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };
  };
}

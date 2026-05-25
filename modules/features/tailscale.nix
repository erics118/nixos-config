{
  flake.modules.nixos.tailscale = {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = "server";
      extraUpFlags = [
        "--advertise-exit-node"
        "--ssh"
      ];
    };
  };
}

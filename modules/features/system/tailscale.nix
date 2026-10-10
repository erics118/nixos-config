{
  flake.modules.nixos.tailscale = { pkgs, ... }: {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = "server";
      # extraUpFlags only apply with an authKeyFile, so the exit node goes through `tailscale set`
      extraSetFlags = [
        "--advertise-exit-node"
        # we use normal ssh authentication
        # "--ssh"
      ];
    };

    # this module owns the interface, so it owns trusting it in the firewall
    networking.firewall.trustedInterfaces = [ "tailscale0" ];

    # exit-node forwarding throughput: enable UDP GRO on the uplink each time it comes up
    # https://tailscale.com/s/ethtool-config-udp-gro
    networking.networkmanager.dispatcherScripts = [
      {
        source = pkgs.writeShellScript "tailscale-udp-gro" ''
          [ "$2" = up ] || exit 0
          dev=$(${pkgs.iproute2}/bin/ip -o route get 8.8.8.8 \
            | ${pkgs.gawk}/bin/awk '{for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')
          [ "$dev" = "$DEVICE_IFACE" ] || exit 0
          ${pkgs.ethtool}/bin/ethtool -K "$dev" rx-udp-gro-forwarding on rx-gro-list off || true
        '';
      }
    ];
  };
}

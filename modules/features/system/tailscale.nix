{
  flake.modules.nixos.tailscale = { pkgs, ... }: {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = "server";
      extraUpFlags = [
        "--advertise-exit-node"
        # we use normal ssh authentication
        # "--ssh"
      ];
    };

    # this module owns the interface, so it owns trusting it in the firewall
    networking.firewall.trustedInterfaces = [ "tailscale0" ];

    # exit-node forwarding throughput: enable UDP GRO on the physical NIC
    # https://tailscale.com/s/ethtool-config-udp-gro
    systemd.services.tailscale-udp-gro = {
      description = "Enable UDP GRO forwarding for Tailscale exit-node throughput";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        dev=$(${pkgs.iproute2}/bin/ip -o route get 8.8.8.8 \
          | ${pkgs.gawk}/bin/awk '{for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')
        if [ -n "$dev" ]; then
          ${pkgs.ethtool}/bin/ethtool -K "$dev" rx-udp-gro-forwarding on rx-gro-list off || true
        fi
      '';
    };
  };
}

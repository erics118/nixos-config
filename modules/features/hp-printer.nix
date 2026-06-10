{
  flake.modules.nixos.hp-printer = { pkgs, ... }: {
    # CUPS + HP drivers (OfficeJet 4620) + mDNS for network discovery.
    services.printing = {
      enable = true;
      drivers = [ pkgs.hplip ];
    };

    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
  };
}

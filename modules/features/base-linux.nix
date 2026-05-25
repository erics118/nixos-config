{
  flake.modules.nixos.base-linux =
    { pkgs, ... }:
    {
      programs.firefox.enable = true;

      # Printing: CUPS + HP drivers (OfficeJet 4620) + mDNS for network discovery.
      services.printing = {
        enable = true;
        drivers = [ pkgs.hplip ];
      };
      services.avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };

      security.rtkit.enable = true;
      services.pulseaudio.enable = false;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };

      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
      };
      services.blueman.enable = true;  # tray applet + pairing UI
    };
}

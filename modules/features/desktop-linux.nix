{
  flake.modules.nixos.desktop-linux = {
    programs.firefox.enable = true;

    security.rtkit.enable = true;
    services = {
      pulseaudio.enable = false;
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };
      blueman.enable = true; # tray applet + pairing UI
    };

    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
}

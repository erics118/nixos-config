{
  flake.modules.nixos.desktop-gnome = {
    programs.firefox.enable = true;

    services = {
      xserver.enable = true;

      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;

      xserver.xkb = {
        layout = "us";
        variant = "";
      };

      printing.enable = true;

      pulseaudio.enable = false;
      rtkit.enable = true;
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };
    };
  };
}

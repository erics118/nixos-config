{
  flake.modules.homeManager.gnome = {
    programs.gnome-terminal = {
      enable = true;
      profile."b1dcc9dd-5262-4d8d-a863-c897e6d979b9" = {
        default = true;
        visibleName = "Default";
        font = "Hack Nerd Font Mono 12";
      };
    };
  };

  flake.modules.nixos.gnome = {
    programs.firefox.enable = true;

    security.rtkit.enable = true;

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
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };
    };
  };
}

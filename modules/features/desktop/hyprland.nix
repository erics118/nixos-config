{
  flake.modules.homeManager.hyprland = { pkgs, repoFile, ... }: {
    home.file.".config/hypr".source = repoFile "modules/eric/desktop/hyprland";

    # Fixes the "Hyprland logo" default cursor. catppuccin-cursors is XCursor-only;
    # Hyprland falls back to XCursor when no hyprcursor theme is found.
    home.pointerCursor = {
      enable = true;
      package = pkgs.catppuccin-cursors.mochaDark;
      name = "catppuccin-mocha-dark-cursors";
      size = 24;
      gtk.enable = true;
      x11.enable = true;
    };

    # System-wide dark mode: GTK apps read these, Qt6 + Firefox + Chrome
    # read color-scheme via xdg-desktop-portal-gtk.
    gtk = {
      enable = true;
      gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
      gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
    };

    dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };

  flake.modules.nixos.hyprland = { config, pkgs, ... }: {
    programs.hyprland.enable = true;
    programs.hyprland.withUWSM = true; # systemd-managed session
    programs.dconf.enable = true; # required for HM dconf.settings to persist
    services.gvfs.enable = true; # trash, USB mount, sftp:// for nautilus

    # xdg-desktop-portal-hyprland is pulled in by programs.hyprland;
    # add the GTK portal for file pickers / settings.
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    # greetd + tuigreet: minimal TTY greeter that launches Hyprland.
    services.greetd = {
      enable = true;
      settings.default_session = {
        # manually specify sessions to prevent duplication
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks --sessions ${config.services.displayManager.sessionData.desktops}/share/xsessions:${config.services.displayManager.sessionData.desktops}/share/wayland-sessions --cmd 'uwsm start hyprland-uwsm.desktop'";
        user = "greeter";
      };
    };

    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
    ];

    environment.systemPackages = with pkgs; [
      wezterm # terminal
      fuzzel # app launcher (SUPER+D)
      nautilus # file manager (SUPER+E)
      hyprlock # screen lock (SUPER+L)
      hypridle # idle daemon (autolock + dpms)
      hyprpaper # wallpaper daemon
      grim # backend for grimblast
      slurp # area selector (used by grimblast area mode)
      wl-clipboard # wl-copy (used by grimblast copy mode)
      brightnessctl # XF86MonBrightness*
      playerctl # XF86AudioPlay/Next/Prev
      libnotify # notify-send (grimblast --notify)
      swaynotificationcenter # notification daemon (swaync)
      hyprpolkitagent # polkit auth agent
      hyprshutdown # graceful logout (SUPER+SHIFT+Q)
      hyprland-qt-support # QML style for hypr* Qt6 apps
      qt5.qtwayland # Qt5 Wayland plugin
      qt6.qtwayland # Qt6 Wayland plugin
      pkgs.inputs.hyprland-contrib.grimblast # screenshot helper (hyprwm/contrib)
      pkgs.inputs.hyprland-contrib.hdrop # dropdown-app toggler (hyprwm/contrib)
    ];

    environment.sessionVariables.NIXOS_OZONE_WL = "1";
  };
}

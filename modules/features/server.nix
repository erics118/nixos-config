{
  flake.modules.nixos.server = {
    systemd.sleep.settings.Sleep = {
      AllowSuspend = "no";
    };

    services.smartd = {
      enable = true;
      autodetect = true;
    };
  };
}

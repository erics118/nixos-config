{
  flake.modules.nixos.server = {
    systemd.sleep.settings.Sleep = {
      AllowSuspend = "no";
    };

    services.smartd = {
      enable = true;
      autodetect = true;
    };

    networking.interfaces.enp5s0.wakeOnLan.enable = true;
  };
}

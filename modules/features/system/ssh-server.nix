{
  flake.modules.nixos.ssh-server = {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        PubkeyAuthentication = true;
        X11Forwarding = false;
        UseDns = false;
        UsePAM = true;
      };
    };

    programs.mosh = {
      enable = true;
    };
  };
}

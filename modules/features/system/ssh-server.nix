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

    services.eternal-terminal.enable = true;

    # module has no openFirewall option, so open et's tcp port manually
    networking.firewall.allowedTCPPorts = [ 2022 ];
  };
}

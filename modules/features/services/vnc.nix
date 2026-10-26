{
  flake.modules.nixos.vnc =
    { pkgs, config, ... }:
    let
      port = 5900;
      subdomain = "desktop";
      keyFile = "${config.users.users.eric.home}/.local/state/wayvnc/rsa_key.pem";
      # relax_encryption adds apple dh, the only wayvnc login type novnc speaks
      configFile = pkgs.writeText "wayvnc.conf" ''
        address=ws:127.0.0.1
        port=${toString port}
        enable_auth=true
        enable_pam=true
        relax_encryption=true
        rsa_private_key_file=${keyFile}
      '';
    in
    {
      # adds the wayvnc pam service, so novnc logs in with eric's password
      programs.wayvnc.enable = true;

      # started from the hyprland session once the headless output exists, like sunshine
      systemd.user.services.wayvnc = {
        description = "wayvnc VNC server";
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        path = [ pkgs.openssh ];
        serviceConfig = {
          StateDirectory = "wayvnc";
          ExecStartPre = pkgs.writeShellScript "wayvnc-key" ''
            [ -e ${keyFile} ] || ssh-keygen -m pem -t rsa -N "" -f ${keyFile}
          '';
          ExecStart = "${config.programs.wayvnc.package}/bin/wayvnc -C ${configFile} -o agent";
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };

      # novnc has no index page, so the root opens the client and connects
      services.caddy.virtualHosts."${subdomain}.${config.homelabDomain}".extraConfig = ''
        root * ${pkgs.novnc}/share/webapps/novnc
        redir / /vnc.html?autoconnect=true&resize=scale
        @ws path /websockify
        reverse_proxy @ws 127.0.0.1:${toString port}
        file_server
      '';

      # proxy is off since the vhost above also serves files, gatus still checks the port
      # href points homepage's status check at the novnc page, since the port only speaks websocket
      homepageTiles = [
        {
          name = "Desktop";
          group = "Apps";
          inherit port subdomain;
          href = "https://${subdomain}.${config.homelabDomain}";
          proxy = false;
          description = "Remote desktop";
          icon = "novnc.svg";
        }
      ];
    };
}

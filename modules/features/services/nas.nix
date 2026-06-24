{
  flake.modules.nixos.nas = {
    # NOTE: hdparm head-parking control (-B/-S) is intentionally omitted. this
    # drive's USB-SATA bridge rejects those commands (SG_IO bad/missing sense data),
    # so the setting has no effect. If Load_Cycle_Count climbs, use hd-idle instead.

    # TODO: make the Samba password declarative via sops instead of the
    # one-time `smbpasswd -a eric`. Add secret "smb/eric" in sops.nix + secrets.yaml,
    # then a oneshot that re-asserts it (inner fn needs { config, pkgs, ... }):
    #   systemd.services.samba-passwd = {
    #     after = [ "samba-smbd.service" ]; wantedBy = [ "multi-user.target" ];
    #     serviceConfig.Type = "oneshot";
    #     script = "pw=$(cat <secret.path>); printf '%s\n%s\n' \"$pw\" \"$pw\" | smbpasswd -s -a eric";
    #   };
    # Trade-off: sops becomes source of truth and resets the password on every switch.

    systemd.tmpfiles.rules = [ "d /mnt/external/timemachine 0750 eric users -" ];

    services.samba = {
      enable = true;
      openFirewall = true;
      settings = {
        global = {
          "workgroup" = "WORKGROUP";
          "server string" = "narwhal";
          "server role" = "standalone server";
          "map to guest" = "Never";
          "vfs objects" = "catia fruit streams_xattr";
          "fruit:metadata" = "stream";
          "fruit:model" = "MacSamba";
          "fruit:posix rename" = "yes";
          "fruit:veto appledouble" = "no";
          "fruit:wipe intentionally left blank rfork" = "yes";
          "fruit:delete empty adfiles" = "yes";
        };
        timemachine = {
          "path" = "/mnt/external/timemachine";
          "valid users" = "eric";
          "browseable" = "no";
          "writable" = "yes";
          "fruit:time machine" = "yes";
          "fruit:time machine max size" = "1400G";
        };
      };
    };

    # Advertise Time Machine share over mDNS so Macs find it automatically
    services.avahi = {
      enable = true;
      openFirewall = true;
      publish = {
        enable = true;
        userServices = true;
      };
      extraServiceFiles = {
        timemachine = ''
          <?xml version="1.0" standalone='no'?>
          <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
          <service-group>
            <name replace-wildcards="yes">%h</name>
            <service>
              <type>_smb._tcp</type>
              <port>445</port>
            </service>
            <service>
              <type>_adisk._tcp</type>
              <txt-record>sys=waMa=0,adVF=0x100</txt-record>
              <txt-record>dk0=adVN=Time Machine,adVF=0x82</txt-record>
            </service>
            <service>
              <type>_device-info._tcp</type>
              <port>0</port>
              <txt-record>model=MacSamba</txt-record>
            </service>
          </service-group>
        '';
      };
    };
  };
}

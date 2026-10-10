{
  flake.modules.nixos.nas = { config, ... }: {
    # NOTE: hdparm head-parking control (-B/-S) is intentionally omitted. this
    # drive's USB-SATA bridge rejects those commands (SG_IO bad/missing sense data),
    # so the setting has no effect. If Load_Cycle_Count climbs, use hd-idle instead.

    # sops is the source of truth, so a password set by hand with smbpasswd is reset on the next change
    sops.secrets."samba/eric".restartUnits = [ "samba-passwd.service" ];

    systemd.services.samba-passwd = {
      description = "Set eric's samba password from sops";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [ config.services.samba.package ];
      script = ''
        pw=$(cat ${config.sops.secrets."samba/eric".path})
        printf '%s\n%s\n' "$pw" "$pw" | smbpasswd -s -a eric
      '';
    };

    systemd.tmpfiles.rules = [ "d /mnt/external/timemachine 0750 eric users -" ];

    # /mnt/external is nofail, so without the disk backups would land on the root fs
    systemd.services.samba-smbd.unitConfig.RequiresMountsFor = [ "/mnt/external" ];

    services.samba = {
      enable = true;
      openFirewall = true;
      settings = {
        global = {
          "workgroup" = "WORKGROUP";
          "server string" = config.networking.hostName;
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
          "fruit:time machine max size" = "2T";
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

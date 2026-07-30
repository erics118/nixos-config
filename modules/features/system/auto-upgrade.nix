{
  flake.modules.nixos.auto-upgrade = { config, pkgs, ... }: {
    # the upgrade unit runs as root, which evaluates the flake and so needs
    # its own read-only deploy key for the private input. the key is placed
    # by hand, not via sops: the secret would live in the very repo the key
    # is needed to fetch
    programs.ssh = {
      knownHosts."github.com".publicKey =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

      extraConfig = ''
        Match localuser root host github.com
          IdentityFile /root/.ssh/id_deploy
          IdentitiesOnly yes
      '';
    };

    system.autoUpgrade = {
      enable = true;
      # --refresh and --flake are appended by the autoUpgrade module itself
      flake = "github:erics118/nixos-config#${config.networking.hostName}";
      # every 6 hours
      dates = "0/6:00";
    };

    # if fail after 3 tries, revert back to a previous generation
    boot.loader.systemd-boot.bootCounting.enable = true;

    # notify on failure via ntfy
    systemd.services.nixos-upgrade.onFailure = [ "nixos-upgrade-notify.service" ];

    systemd.services.nixos-upgrade-notify = {
      description = "notify that the unattended upgrade failed";
      serviceConfig.Type = "oneshot";
      script = ''
        topic=$(cat /run/secrets/ntfy/nix 2>/dev/null) || exit 0
        [ -n "$topic" ] || exit 0
        ${pkgs.curl}/bin/curl -s -o /dev/null \
          -H "Title: nixos-upgrade failed on ${config.networking.hostName}" \
          -H "Tags: nix,x" \
          -d "nixos-upgrade failed, see journalctl -u nixos-upgrade" \
          "https://ntfy.sh/$topic"
      '';
    };
  };
}

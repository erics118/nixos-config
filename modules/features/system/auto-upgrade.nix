{
  flake.modules.nixos.auto-upgrade =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      checkout = "/home/eric/nixos-config";
      privateCheckout = "/home/eric/nixos-config-private";
      bootCritical = [
        "sshd.service"
      ]
      ++ lib.optional config.services.tailscale.enable "tailscaled.service";
    in
    {
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
        flake = "${checkout}#${config.networking.hostName}";
        # every 6 hours
        dates = "0/6:00";
      };

      # a generation that fails to reach boot-complete.target 3 times falls back to the previous one
      boot.loader.systemd-boot.bootCounting.enable = true;

      # a generation without ssh or tailscale is unreachable remotely, so it must not count as booted
      # a oneshot checks them instead of requiring the services, since a required unit's restart
      # restarts boot-complete.target and systemd-bless-boot, which fails once the boot is blessed
      systemd.services.boot-critical-check = {
        requiredBy = [ "boot-complete.target" ];
        before = [ "boot-complete.target" ];
        after = bootCritical;
        restartIfChanged = false;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = "${config.systemd.package}/bin/systemctl is-active ${lib.concatStringsSep " " bootCritical}";
      };

      systemd.services.nixos-upgrade = {
        # the upgrade runs as root but builds from eric's checkout
        # nix's libgit2 fetches the git+file flake as root and refuses a repo owned by another user unless the owner matches $SUDO_UID
        environment.SUDO_UID = "1000";
        # sync checkout
        preStart = ''
          branch=$(runuser -u eric -- git -C ${checkout} symbolic-ref --short HEAD)
          if [ "$branch" != "main" ]; then
            echo "checkout is on '$branch', not main; refusing to deploy" >&2
            exit 1
          fi
          if ! runuser -u eric -- git -C ${checkout} diff --quiet HEAD; then
            echo "checkout has local modifications; refusing to deploy" >&2
            exit 1
          fi
          runuser -u eric -- git -C ${checkout} pull --ff-only
          if [ "$(runuser -u eric -- git -C ${checkout} rev-parse HEAD)" != "$(runuser -u eric -- git -C ${checkout} rev-parse origin/main)" ]; then
            echo "checkout has commits not on origin/main; refusing to deploy" >&2
            exit 1
          fi
          # the build uses the locked private input, so only its live links go stale here
          runuser -u eric -- git -C ${privateCheckout} pull --ff-only \
            || echo "private checkout did not fast-forward; its live links stay stale" >&2
        '';
        path = [
          pkgs.git
          pkgs.openssh
          pkgs.util-linux
        ];
        # notify on failure via ntfy
        onFailure = [ "nixos-upgrade-notify.service" ];
      };

      systemd.services.nixos-upgrade-notify = {
        description = "notify that the unattended upgrade failed";
        serviceConfig.Type = "oneshot";
        # the token reaches curl through an fd, so it never shows in its argv
        # --fail turns a rejected post into a failed unit, and the retries cover ntfy restarting in the same switch
        script = ''
          ${pkgs.curl}/bin/curl -s -o /dev/null --fail --retry 3 --retry-all-errors \
            -H @<(printf 'Authorization: Bearer %s\n' "$(cat ${config.sops.secrets."ntfy/token".path})") \
            -H "Title: nixos-upgrade failed on ${config.networking.hostName}" \
            -H "Tags: nix,x" \
            -d "nixos-upgrade failed, see journalctl -u nixos-upgrade" \
            "https://${config.ntfyHost}/nix"
        '';
      };
    };
}

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
        # a merge just before the timer fires has ci still running, so skip that run without failing
        # exit 1 in ExecCondition skips the unit and leaves it unfailed, so onFailure never fires
        serviceConfig.ExecCondition = pkgs.writeShellScript "nixos-upgrade-ci-pending" ''
          runuser -u eric -- git -C ${checkout} fetch --quiet origin main
          sha=$(runuser -u eric -- git -C ${checkout} rev-parse origin/main) || exit 0
          if curl -sf "https://api.github.com/repos/erics118/nixos-config/actions/workflows/check.yml/runs?head_sha=$sha" \
            | jq -e '(any(.workflow_runs[]; .conclusion == "success") | not) and any(.workflow_runs[]; .status != "completed")' >/dev/null; then
            echo "check.yml is still running on $sha; skipping until the next run" >&2
            exit 1
          fi
        '';
        # sync checkout
        preStart = ''
          # nixos-upgrade-rollback restores these if the run fails after switching
          readlink -f /nix/var/nix/profiles/system /run/current-system >/run/nixos-upgrade-prev
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
          # two lock prs can each pass ci and merge into a combination ci never built
          sha=$(runuser -u eric -- git -C ${checkout} rev-parse HEAD)
          if ! curl -sf "https://api.github.com/repos/erics118/nixos-config/actions/workflows/check.yml/runs?head_sha=$sha&status=success" \
            | jq -e '.total_count > 0' >/dev/null; then
            echo "check.yml has not passed on $sha; refusing to deploy" >&2
            exit 1
          fi
          # the build uses the locked private input, so only its live links go stale here
          runuser -u eric -- git -C ${privateCheckout} pull --ff-only \
            || echo "private checkout did not fast-forward; its live links stay stale" >&2
        '';
        path = [
          pkgs.curl
          pkgs.git
          pkgs.jq
          pkgs.openssh
          pkgs.util-linux
        ];
        # notify on failure via ntfy
        onFailure = [
          "nixos-upgrade-rollback.service"
          "nixos-upgrade-notify.service"
        ];
      };

      systemd.services.nixos-upgrade-rollback = {
        description = "roll back a failed unattended upgrade";
        serviceConfig.Type = "oneshot";
        # the switch below must not stop or restart this unit
        restartIfChanged = false;
        unitConfig.X-StopOnRemoval = false;
        # a run that failed before switching left both links as they were
        script = ''
          { read -r profile; read -r current; } </run/nixos-upgrade-prev
          if [ "$(readlink -f /nix/var/nix/profiles/system)" != "$profile" ] \
            || [ "$(readlink -f /run/current-system)" != "$current" ]; then
            ${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --set "$profile"
            "$profile/bin/switch-to-configuration" switch
          fi
        '';
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

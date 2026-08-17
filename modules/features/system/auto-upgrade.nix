{
  flake.modules.nixos.auto-upgrade =
    { config, pkgs, ... }:
    let
      checkout = "/home/eric/.flake";
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

      # if fail after 3 tries, revert back to a previous generation
      boot.loader.systemd-boot.bootCounting.enable = true;

      systemd.services.nixos-upgrade = {
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
        script = ''
          ${pkgs.curl}/bin/curl -s -o /dev/null \
            -H "Authorization: Bearer $(cat ${config.sops.secrets."ntfy/token".path})" \
            -H "Title: nixos-upgrade failed on ${config.networking.hostName}" \
            -H "Tags: nix,x" \
            -d "nixos-upgrade failed, see journalctl -u nixos-upgrade" \
            "https://${config.ntfyHost}/nix"
        '';
      };
    };
}

{
  flake.modules.nixos.sunshine =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      # sunshine synthesizes mouse/keyboard through /dev/uinput, and reads back the
      # virtual devices it creates under /dev/input
      users.users.eric.extraGroups = [
        "input"
        "uinput"
      ];

      # drop the module's cap_sys_admin, we only capture through wlr screencopy
      security.wrappers.sunshine.capabilities = lib.mkForce "cap_sys_nice+ep";

      services.sunshine = {
        enable = true;

        # nvenc is gated behind SUNSHINE_ENABLE_CUDA, off in the default build.
        # nvidia-vaapi-driver is decode-only, so cuda is the only path to hw encode
        package = pkgs.sunshine.override { cudaSupport = true; };

        # wlr screencopy needs no drm/kms grab, but this is the only switch that
        # routes ExecStart through security.wrappers, so we can grant cap_sys_nice
        # below instead. sunshine wants it for a high-priority egl context and to
        # renice its capture/encode threads, both of which affect frame pacing
        capSysAdmin = true;

        # started from the hyprland session instead, once the headless output exists.
        # sunshine caches output_name at process start, so it must come second
        autoStart = false;

        settings = {
          sunshine_name = config.networking.hostName;
          capture = "wlr";
          encoder = "nvenc";
          # virtual monitor, keeps the stream off the physical display
          output_name = "HEADLESS-1";

          # web ui is only reached over tailscale, which csrf rejects as a non-default origin
          # magicdns name only, the tailnet address can change
          csrf_allowed_origins = "https://narwhal.dolphin-sailfin.ts.net:47990";
        };
      };
    };
}

{ config, ... }:
let
  inherit (config) tailnetDomain;
in
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

      # upstream sunshine sets the obsolete services.avahi.publish.enable/userServices
      # null them to drop the eval warning and set what they mapped to
      services.avahi.publish = {
        enable = null;
        userServices = null;
      };
      services.avahi.settings.publish = {
        disable-publishing = lib.mkDefault false;
        disable-user-service-publishing = lib.mkDefault false;
        publish-addresses = lib.mkDefault true;
      };

      # openFirewall stays off: tailscale.nix trusts tailscale0, so only the tailnet reaches it
      services.sunshine = {
        enable = true;

        # nvenc is gated behind SUNSHINE_ENABLE_CUDA, off in the default build.
        # nvidia-vaapi-driver is decode-only, so cuda is the only path to hw encode
        package = pkgs.sunshine.override { cudaSupport = true; };

        # wlr screencopy needs no drm/kms grab, but this is the only switch that
        # routes ExecStart through security.wrappers, which grant cap_sys_nice above
        # sunshine uses it for a high-priority egl context and to renice capture/encode threads
        capSysAdmin = true;

        # started from the hyprland session instead, once the headless output exists.
        # sunshine caches output_name at process start, so it must come second
        autoStart = false;

        settings = {
          sunshine_name = config.networking.hostName;
          capture = "wlr";
          encoder = "nvenc";
          # the headless output hyprland.lua creates, keeps the stream off the physical display
          output_name = "agent";

          # web ui is only reached over tailscale, which csrf rejects as a non-default origin
          # magicdns name only, the tailnet address can change
          csrf_allowed_origins = "https://${config.networking.hostName}.${tailnetDomain}:47990";
        };

        # resize the agent output to the client's pixels on connect so a retina mac gets a hidpi desktop
        applications.apps = [
          {
            name = "Desktop";
            prep-cmd = [
              {
                do = toString (
                  pkgs.writeShellScript "agent-fit-client" ''
                    ${config.programs.hyprland.package}/bin/hyprctl eval "hl.monitor({ output = \"agent\", mode = \"''${SUNSHINE_CLIENT_WIDTH}x''${SUNSHINE_CLIENT_HEIGHT}@''${SUNSHINE_CLIENT_FPS}\", position = \"0x0\", scale = 2 })"
                  ''
                );
                undo = "";
              }
            ];
          }
        ];
      };
    };
}

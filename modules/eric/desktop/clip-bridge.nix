let
  # gates both the mac listener and the remote shims, which would only time out without it
  enable = true;

  # the mac serves its clipboard over tailscale and remotes pull from it
  port = "5556";
  shimDir = ".local/share/clip-bridge";
in
{
  flake.modules.homeManager.base =
    { pkgs, lib, ... }:
    let
      # the mac is the ssh client, so its tailnet address is the first field of SSH_CONNECTION
      # inside tmux the shell's copy goes stale on reattach, so prefer the session's
      findMac = ''
        conn=
        [ -n "''${TMUX:-}" ] && conn=$(tmux show-environment SSH_CONNECTION 2>/dev/null | sed -n 's/^SSH_CONNECTION=//p')
        [ -n "$conn" ] || conn=''${SSH_CONNECTION:-}
        mac=''${conn%% *}
      '';

      # remote-side sender: request a mode, stream the bytes back
      # -w 2 keeps paste from hanging when the mac is asleep or off-tailnet
      send = ''${pkgs.nmap}/bin/ncat -w 2 "$mac" ${port} 2>/dev/null'';

      mkShim = text: {
        executable = true;
        inherit text;
      };

      # copy-out rides osc 52 through the terminal to the mac clipboard
      osc52 = ''printf '\033]52;c;%s\a' "$(base64 | tr -d '\n')" > /dev/tty 2>/dev/null'';

      # claude tries xclip first, then wl-paste; both read from the mac
      wlPaste = mkShim ''
        #!/bin/sh
        ${findMac}
        case " $* " in
          *" -l "*|*" --list-types "*) req=list ;;
          *image/*) req=png ;;
          *) req=text ;;
        esac
        printf '%s\n' "$req" | ${send}
      '';

      xclip = mkShim ''
        #!/bin/sh
        case " $* " in
          *" -o "*)
            ${findMac}
            case " $* " in
              *TARGETS*) req=list ;;
              *image/*) req=png ;;
              *) req=text ;;
            esac
            printf '%s\n' "$req" | ${send} ;;
          *) ${osc52} ;;
        esac
      '';

      wlCopy = mkShim ''
        #!/bin/sh
        ${osc52}
      '';
    in
    {
      home.file = lib.mkIf (enable && pkgs.stdenv.hostPlatform.isLinux) {
        "${shimDir}/wl-paste" = wlPaste;
        "${shimDir}/xclip" = xclip;
        "${shimDir}/wl-copy" = wlCopy;
      };

      # only route the clipboard to the mac over ssh, never on the local session
      programs.zsh.initContent = lib.mkIf (enable && pkgs.stdenv.hostPlatform.isLinux) (
        lib.mkAfter ''
          claude() {
            if [ -n "$SSH_CONNECTION" ]; then
              PATH="$HOME/${shimDir}:$PATH" command claude "$@"
            else
              command claude "$@"
            fi
          }
        ''
      );
    };

  flake.modules.homeManager.darwin =
    { pkgs, ... }:
    let
      # mac-side responder, run per connection by ncat
      # serves only devices owned by the same tailscale login as this mac, on any tailnet it joins
      # the tailscale cli comes from the tailscale app, outside launchd's PATH
      clipServe = pkgs.writeShellApplication {
        name = "clip-bridge-serve";
        runtimeInputs = [
          pkgs.pngpaste
          pkgs.jq
        ];
        text = ''
          ip="''${NCAT_REMOTE_ADDR:-}"
          me=$(/usr/local/bin/tailscale status --json | jq -r '.User[(.Self.UserID|tostring)].LoginName') || exit 0
          peer=$(/usr/local/bin/tailscale whois --json "$ip" 2>/dev/null | jq -r '.UserProfile.LoginName // empty') || exit 0
          [ -n "$peer" ] && [ "$peer" = "$me" ] || exit 0

          read -r req
          case "$req" in
            list) if pngpaste - >/dev/null 2>&1; then printf 'image/png\n'; else printf 'text/plain\n'; fi ;;
            png) pngpaste - ;;
            text) /usr/bin/pbpaste ;;
          esac
        '';
      };
    in
    {
      launchd.agents.clip-bridge = {
        inherit enable;
        config = {
          ProgramArguments = [
            "${pkgs.nmap}/bin/ncat"
            "-l"
            "-k"
            "${port}"
            "--sh-exec"
            "${clipServe}/bin/clip-bridge-serve"
          ];
          RunAtLoad = true;
          KeepAlive = true;
        };
      };
    };
}

let
  # orca (mac) serves its clipboard over tailscale; remotes pull from it
  orca = "orca.dolphin-sailfin.ts.net";
  port = "5556";
  shimDir = ".local/share/clip-bridge";
in
{
  flake.modules.homeManager.base =
    { pkgs, lib, ... }:
    let
      # remote-side sender: request a mode, stream the bytes back
      # -w 2 keeps paste from hanging when the mac is asleep or off-tailnet
      send = "${pkgs.nmap}/bin/ncat -w 2 ${orca} ${port} 2>/dev/null";

      mkShim = text: {
        executable = true;
        inherit text;
      };

      # copy-out rides osc 52 through the terminal to the mac clipboard
      osc52 = ''printf '\033]52;c;%s\a' "$(base64 | tr -d '\n')" > /dev/tty 2>/dev/null'';

      # claude tries xclip first, then wl-paste; both read from the mac
      wlPaste = mkShim ''
        #!/bin/sh
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
      home.file = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        "${shimDir}/wl-paste" = wlPaste;
        "${shimDir}/xclip" = xclip;
        "${shimDir}/wl-copy" = wlCopy;
      };

      # only route the clipboard to the mac over ssh, never on the local session
      programs.zsh.initContent = lib.mkIf pkgs.stdenv.hostPlatform.isLinux (
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
      # peer must be inside the tailscale range 100.64.0.0/10
      clipServe = pkgs.writeShellApplication {
        name = "clip-bridge-serve";
        runtimeInputs = [ pkgs.pngpaste ];
        text = ''
          ip="''${NCAT_REMOTE_ADDR:-}"
          o2="''${ip#100.}"
          o2="''${o2%%.*}"
          case "$ip" in
            100.*) { [ "$o2" -ge 64 ] && [ "$o2" -le 127 ]; } || exit 0 ;;
            *) exit 0 ;;
          esac

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
        enable = true;
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

{ config, ... }:
let
  # every host this flake configures, which get tmux-sessions from home-manager
  ownHosts =
    builtins.attrNames config.configurations.nixos ++ builtins.attrNames config.configurations.darwin;
in
{
  # attach to a persistent session on a remote host over mosh or autossh
  flake.modules.homeManager.base =
    { lib, pkgs, ... }:
    let
      # what rtmux installs on hosts outside this config. its store path's name is the version
      remote = pkgs.runCommand "rtmux-remote" { } ''
        install -Dm555 ${./tmux-sessions/tmux-sessions.sh} $out/tmux-sessions
        install -Dm444 ${./rtmux/remote.conf} $out/tmux.conf
      '';
    in
    {
      home.packages = [
        (pkgs.writeShellApplication {
          name = "rtmux";
          runtimeInputs = with pkgs; [
            mosh
            autossh
            openssh
            fzf
            jq
            # gnu awk's BEGINFILE and coreutils' timeout, which macos lacks
            coreutils
            gnugrep
            gawk
            gnused
          ];
          text = ''
            own_hosts=(${lib.escapeShellArgs ownHosts})
            remote_dir=${remote}
          ''
          + builtins.readFile ./rtmux/rtmux.sh;
        })
        # zsh autoloads _rtmux from the profile's site-functions, already on fpath
        (pkgs.runCommand "rtmux-zsh-completion" { } ''
          install -Dm444 ${./rtmux/_rtmux} $out/share/zsh/site-functions/_rtmux
        '')
      ];
    };
}

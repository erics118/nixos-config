{
  # attach to a persistent tmux session on a remote host over mosh
  # -a falls back to autossh
  flake.modules.homeManager.base = { pkgs, ... }: {
    home.packages = [
      (pkgs.writeShellApplication {
        name = "rtmux";
        runtimeInputs = with pkgs; [
          mosh
          autossh
          openssh
        ];
        text = builtins.readFile ./rtmux/rtmux.sh;
      })
      # zsh autoloads _rtmux from the profile's site-functions, already on fpath
      (pkgs.runCommand "rtmux-zsh-completion" { } ''
        install -Dm444 ${./rtmux/_rtmux} $out/share/zsh/site-functions/_rtmux
      '')
    ];
  };
}

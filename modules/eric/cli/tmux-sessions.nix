{
  flake.modules.homeManager.base = { pkgs, ... }: {
    home.packages = [
      (pkgs.runCommand "tmux-sessions" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
        shellcheck -s sh ${./tmux-sessions/tmux-sessions.sh}
        install -Dm555 ${./tmux-sessions/tmux-sessions.sh} $out/bin/tmux-sessions
      '')
    ];
  };
}

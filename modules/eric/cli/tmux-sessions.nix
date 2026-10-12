{
  flake.modules.homeManager.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      home.packages = [
        # the wezterm gui runs it too, and its PATH lacks tmux and may lack grep
        (pkgs.runCommand "tmux-sessions"
          {
            nativeBuildInputs = [
              pkgs.makeWrapper
              pkgs.shellcheck
            ];
          }
          ''
            shellcheck -s sh ${./tmux-sessions/tmux-sessions.sh}
            install -Dm555 ${./tmux-sessions/tmux-sessions.sh} $out/libexec/tmux-sessions
            makeWrapper $out/libexec/tmux-sessions $out/bin/tmux-sessions --prefix PATH : ${
              lib.makeBinPath [
                config.programs.tmux.package
                pkgs.gnugrep
              ]
            }
          ''
        )
      ];
    };
}

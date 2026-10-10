{
  flake.modules.homeManager.base = { pkgs, lib, ... }: {
    home = {
      packages =
        with pkgs;
        [
          # nix
          nixd
          nil # some things require nil for some reason
          statix
          cachix
          deadnix
          home-manager

          # system-wide formatters
          nixfmt
          shfmt

          # global languages/toolchains
          nodejs_24
          python3

          # apps
          _1password-cli

          # system utilities
          nmap
          dust
          rsync
          killall
          ccache
          autossh
          openconnect

          # development
          hyperfine
          onefetch
          yq-go
          scc
          railway
          screen
          poppler # pdf rendering

          # fonts
          nerd-fonts.hack
        ]
        ++ lib.optionals stdenv.hostPlatform.isDarwin [
          # gnu tools under their plain names, ahead of the BSD ones macOS ships
          coreutils
          gnused
          gawk

          # cli tools
          mosh
          glow
          serve
          terminal-notifier
          blueutil

          # fonts
          sketchybar-app-font

          # development
          lua5_5 # for sketchybar

          # apps
          espanso
        ]
        ++ lib.optionals stdenv.hostPlatform.isLinux [
          # sandboxing
          bubblewrap
        ];

      sessionPath = [ "$HOME/.local/bin" ];

      stateVersion = "25.11";
    };
  };
}

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
          # llvmPackages_22.clang-tools # clang-format, clang-tidy, clangd

          # global languages/toolchains
          # clang_22
          # typescript-language-server
          nodejs_24
          python3Minimal
          # cmake
          # ninja
          # pkg-config

          # apps
          _1password-cli

          # system utilities
          nmap
          dust
          rsync
          killall
          ccache
          autossh

          # development
          hyperfine
          onefetch
          yq-go
          yazi
          scc
          railway
          docker-sbx
          screen

          # fonts
          nerd-fonts.hack
        ]
        ++ lib.optionals stdenv.hostPlatform.isDarwin [
          # gnu coreutils with g-prefix (gls, gdate, ...) since macOS ships BSD coreutils
          coreutils-prefixed

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

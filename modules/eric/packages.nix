{
  flake.modules.homeManager.base =
    { pkgs, lib, ... }:
    {
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
            nvd
            nix-tree
            nix-du
            manix

            # interactive fuzzy search over nixpkgs / NixOS / home-manager
            nix-search-tv
            (pkgs.writeShellApplication {
              name = "ns";
              runtimeInputs = with pkgs; [
                fzf
                nix-search-tv
              ];
              text = builtins.readFile "${pkgs.nix-search-tv.src}/nixpkgs.sh";
            })

            # system-wide formatters
            nixfmt
            shfmt

            # apps
            _1password-cli
            nodejs-slim_24 # for agent context protocol

            # system utilities
            nmap
            dust
            rsync
            wget
            killall
            ccache

            # converting
            imagemagick
            pandoc
            ffmpeg
            yt-dlp

            # development
            hyperfine
            onefetch
            python3
            httpie
            yq-go
            watchexec
            delta
            yazi
            scc
            adversarial-review

            # fonts
            nerd-fonts.hack
          ]
          ++ lib.optionals stdenv.hostPlatform.isDarwin [

            # gnu coreutils with g-prefix (gls, gdate, ...) since macOS ships BSD coreutils
            coreutils-prefixed

            # build tools
            cmake
            ninja
            pkg-config

            # cli tools
            mosh
            glow
            prek
            nextdns
            supabase-cli
            spicetify-cli
            serve

            # fonts
            sketchybar-app-font

            # development
            lua5_5 # for sketchybar
            # apps
            espanso
          ];

        sessionPath = [ "$HOME/.local/bin" ];

        stateVersion = "25.11";
      };
    };
}

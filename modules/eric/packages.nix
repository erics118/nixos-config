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
            nixfmt
            statix
            cachix
            comma
            home-manager

            # apps
            _1password-cli
            nodejs-slim_24 # for agent context protocol

            # system utilities
            coreutils-prefixed
            nmap
            dust
            rsync
            wget
            killall

            # converting
            imagemagick
            pandoc
            ffmpeg
            yt-dlp

            # development
            hyperfine
            onefetch
            shfmt
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

            # build tools
            cmake
            ninja
            pkg-config

            # cli tools
            mosh
            glow
            ltex-ls
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

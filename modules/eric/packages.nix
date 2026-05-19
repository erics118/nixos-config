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
            httpie
            yq-go
            watchexec
            delta
            yazi
            scc
            adversarial-review
          ]
          ++ lib.optionals stdenv.hostPlatform.isDarwin [
            mosh
          ];

        sessionPath = [ "$HOME/.local/bin" ];

        stateVersion = "25.11";
      };
    };
}

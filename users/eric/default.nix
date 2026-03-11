{
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./catppuccin.nix
    ./cli
    ./git.nix
    ./nixvim.nix
    ./shell.nix
    ./ssh.nix
    ./nh.nix
  ];

  home.packages =
    with pkgs;
    [
      # cli tools
      httpie
      cachix
      killall
      yq-go
      shfmt
      scc

      # nix cli
      nixd
      nixfmt

      # apps
      _1password-cli
      codex

      # utilities
      hyperfine
      imagemagick
      mosh
      nmap
      onefetch
      pandoc
      watchexec
      yazi
      yt-dlp

      # language servers & formatters
      #   pyright
      #   lua-language-server
      #   typescript-language-server
      #   yaml-language-server
      #   tailwindcss-language-server
      #   taplo
      #   rust-analyzer
      #   ruff
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      xclip
      _1password-gui
    ];

  home.sessionPath = [ "$HOME/.local/bin" ];

  home.stateVersion = "25.11";
}

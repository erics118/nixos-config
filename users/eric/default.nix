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
      gemini-cli

      # nix cli
      nixd
      nil # some things require nil for some reason
      nixfmt

      # apps
      _1password-cli
      nodejs-slim_24 # for agent context protocol

      # utilities
      hyperfine
      imagemagick
      nmap
      onefetch
      pandoc
      watchexec
      yazi
      yt-dlp
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      mosh
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      xclip
      _1password-gui
    ];

  home.sessionPath = [ "$HOME/.local/bin" ];

  home.stateVersion = "25.11";
}

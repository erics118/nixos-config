{
  pkgs,
  ...
}:

{
  imports = [
    ./catppuccin.nix
    ./cli.nix
    ./git.nix
    ./nixvim.nix
    ./shell.nix
    ./ssh.nix
    ./nh.nix
  ];

  home.packages = with pkgs; [
    # cli tools
    httpie
    cachix
    killall
    xclip
    ntfy-sh
    railway
    tokei
    yq-go
    github-copilot-cli
    fastfetch
    shfmt

    # nix cli
    nixd
    nixfmt

    # apps
    _1password-gui
    _1password-cli
  ];

  home.stateVersion = "25.11";
}

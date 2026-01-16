{
  pkgs,
  ...
}:

{
  imports = [
    ./git.nix
    ./nixvim.nix
    ./ssh.nix
    ./shell.nix
    ./catppuccin.nix
    # ./sops.nix
  ];

  home.packages = with pkgs; [

    # dev tools
    gnumake
    yarn
    nodejs
    gccgo15
    ninja

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

    # nix cli
    nixfmt-rfc-style
    nixd

    # apps
    _1password-gui
    _1password-cli
  ];

  home.shell.enableZshIntegration = true;

  home.stateVersion = "25.11";
}

{ pkgs, ... }:
{
  home.packages = with pkgs; [
    xclip
    _1password-gui
    wezterm
  ];
}

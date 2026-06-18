let
  homeConfig = { repoFile, ... }: {
    # single live-symlink so edits to lua take effect without a rebuild
    home.file.".config/wezterm".source = repoFile "modules/eric/desktop/wezterm";
  };
in
{
  flake.modules.darwin.base = { pkgs, ... }: { environment.systemPackages = [ pkgs.wezterm ]; };

  flake.modules.homeManager.darwin = homeConfig;
  flake.modules.homeManager.desktop-hyprland = homeConfig;
}

{
  flake.modules.darwin.base =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.wezterm ];
    };

  flake.modules.homeManager.base =
    { config, ... }:
    {
      # single live-symlink so edits to lua take effect without a rebuild
      home.file.".config/wezterm".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.flake/modules/eric/desktop/wezterm";
    };
}

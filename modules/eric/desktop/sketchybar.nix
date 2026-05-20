{
  flake.modules.homeManager.darwin =
    { config, ... }:
    {
      # single live-symlink: edits to lua/scripts take effect without a rebuild
      # C helpers continue to build in place via helpers/*/makefile
      home.file.".config/sketchybar".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.flake/modules/eric/desktop/sketchybar";
    };
}

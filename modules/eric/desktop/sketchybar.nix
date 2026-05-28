{
  flake.modules.homeManager.darwin =
    { config, ... }:
    {
      # single live-symlink: edits to lua/scripts take effect without a rebuild
      # C helpers continue to build in place via helpers/*/makefile
      home.file.".config/sketchybar".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.flake/modules/eric/desktop/sketchybar";
    };

  flake.modules.darwin.base = {
    launchd.user.agents.sketchybar = {
      serviceConfig = {
        ProgramArguments = [ "/opt/homebrew/opt/sketchybar/bin/sketchybar" ];
        WorkingDirectory = "/Users/eric/.config/sketchybar";
        EnvironmentVariables = {
          LANG = "en_US.UTF-8";
          PATH = "/opt/homebrew/bin:/opt/homebrew/sbin:/Users/eric/.local/bin:/Users/eric/.nix-profile/bin:/etc/profiles/per-user/eric/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        };
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Interactive";
        StandardOutPath = "/opt/homebrew/var/log/sketchybar/sketchybar.out.log";
        StandardErrorPath = "/opt/homebrew/var/log/sketchybar/sketchybar.err.log";
      };
    };
  };
}

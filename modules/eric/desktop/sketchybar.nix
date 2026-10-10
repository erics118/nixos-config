{
  flake.modules.homeManager.darwin = { pkgs, repoFile, ... }: {
    # single live-symlink: edits to lua/scripts take effect without a rebuild
    home.file.".config/sketchybar".source = repoFile "modules/eric/desktop/sketchybar";
    # C helpers, so editing their sources needs a switch
    # menus links the private SkyLight framework, which needs the darwin sandbox off
    home.file.".local/share/sketchybar_helpers".source = pkgs.runCommandCC "sketchybar-helpers" { } ''
      mkdir -p $out
      $CC -std=c99 -O3 -o $out/cpu_load ${./sketchybar/helpers/event_providers}/cpu_load/cpu_load.c
      $CC -std=c99 -O3 -fobjc-arc -framework AppKit -o $out/symbol_image ${./sketchybar/helpers/symbol_image/symbol_image.m}
      $CC -std=c99 -O3 -fobjc-arc -F/System/Library/PrivateFrameworks -framework AppKit -framework Carbon -framework SkyLight \
        -o $out/menus ${./sketchybar/helpers/menus/menus.m}
    '';
    # sketchybar's lua module, at the path helpers/init.lua adds to package.cpath
    home.file.".local/share/sketchybar_lua/sketchybar.so".source =
      "${pkgs.sbarlua}/lib/lua/5.5/sketchybar.so";
    # the font's own icon map, so names always match the installed font
    home.file.".local/share/sketchybar-app-font/icon_map.lua".source =
      "${pkgs.sketchybar-app-font}/lib/sketchybar-app-font/icon_map.lua";
  };

  flake.modules.darwin.base =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      environment.systemPackages = [ pkgs.sketchybar ];
      signedAgents.sketchybar = pkgs.sketchybar;

      launchd.user.agents.sketchybar = {
        serviceConfig = {
          Label = "com.erics118.sketchybar";
          ProgramArguments = [ (lib.getExe pkgs.sketchybar) ];
          WorkingDirectory = "/Users/eric/.config/sketchybar";
          EnvironmentVariables = {
            LANG = "en_US.UTF-8";
            PATH = config.launchdUserPath;
          };
          RunAtLoad = true;
          KeepAlive = true;
          ProcessType = "Interactive";
          StandardOutPath = "/tmp/sketchybar_eric.out.log";
          StandardErrorPath = "/tmp/sketchybar_eric.err.log";
        };
      };
    };
}

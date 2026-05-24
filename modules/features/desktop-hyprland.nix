{
  flake.modules.homeManager.desktop-hyprland = {
    wayland.windowManager.hyprland = {
      enable = true;
      package = null;
      portalPackage = null;

      systemd.variables = [ "--all" ];

      settings = {
        "$mod" = "SUPER";
        bind =
          [
            "$mod, Return, exec, kitty"
            "$mod, Q, killactive"
            "$mod, M, exit"
            "$mod, V, togglefloating"
            "$mod, F, fullscreen"
            "$mod, left, movefocus, l"
            "$mod, right, movefocus, r"
            "$mod, up, movefocus, u"
            "$mod, down, movefocus, d"
          ]
          ++ (builtins.concatLists (builtins.genList (
            i:
            let
              ws = i + 1;
            in
            [
              "$mod, code:1${toString i}, workspace, ${toString ws}"
              "$mod SHIFT, code:1${toString i}, movetoworkspace, ${toString ws}"
            ]
          ) 9));
      };
    };
  };

  flake.modules.nixos.desktop-hyprland =
    { pkgs, ... }:
    {
      programs.hyprland.enable = true;

      environment.systemPackages = [ pkgs.kitty ];

      environment.sessionVariables.NIXOS_OZONE_WL = "1";
    };
}

{
  perSystem = { config, pkgs, ... }: {
    devShells = {
      default = pkgs.mkShell {
        packages = with pkgs; [
          config.treefmt.build.wrapper
          lua-language-server
          stylua
          lua5_5
          clang-tools
          gnumake
          go
          gopls
        ];
        # LuaLS stubs for hyprland.lua, read by its .luarc.json
        HYPR_STUBS = pkgs.runCommand "hyprland-lua-stubs" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          python3 ${pkgs.hyprland.src}/meta/generateLuaStubs.py --root ${pkgs.hyprland.src} --output $out/hl.meta.lua
        '';
      };
    };
  };
}

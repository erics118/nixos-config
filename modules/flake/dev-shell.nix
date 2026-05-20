{
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.default = pkgs.mkShell { packages = [ config.treefmt.build.wrapper ]; };

      devShells.sketchybar = pkgs.mkShell {
        packages = with pkgs; [
          lua-language-server
          stylua
          lua5_5
          clang-tools
          gnumake
        ];
      };
    };
}

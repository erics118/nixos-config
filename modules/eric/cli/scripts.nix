let
  # every <dir>/<name>.sh becomes the command <name>
  # runtimeInputs.<name> adds tools beyond the user's PATH, and a key with no matching script fails the build
  scriptsIn =
    { lib, pkgs }:
    dir: runtimeInputs:
    let
      names = map (lib.removeSuffix ".sh") (
        builtins.attrNames (
          lib.filterAttrs (file: type: type == "regular" && lib.hasSuffix ".sh" file) (builtins.readDir dir)
        )
      );
      unknown = lib.subtractLists names (builtins.attrNames runtimeInputs);
    in
    assert lib.assertMsg (unknown == [ ]) "runtimeInputs for missing scripts: ${toString unknown}";
    map (
      name:
      pkgs.writeShellApplication {
        inherit name;
        runtimeInputs = runtimeInputs.${name} or [ ];
        text = builtins.readFile (dir + "/${name}.sh");
      }
    ) names;
in
{
  flake.modules.homeManager.base = { lib, pkgs, ... }: {
    home.packages = scriptsIn { inherit lib pkgs; } ./scripts {
      ask = with pkgs; [
        curl
        jq
        bc
        coreutils
      ];
      # wezterm runs it straight from the gui, whose PATH lacks the user's tools
      tmux-popup = [ pkgs.tmux ];
      mvproj = with pkgs; [
        gnused
        gnugrep
        lsof
      ];
    };
  };

  flake.modules.homeManager.darwin = { lib, pkgs, ... }: {
    home.packages = scriptsIn { inherit lib pkgs; } ./scripts/darwin { };
  };
}

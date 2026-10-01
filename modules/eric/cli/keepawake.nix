{
  flake.modules.homeManager.darwin = { pkgs, ... }: {
    home.packages = [
      (pkgs.writeShellApplication {
        name = "keepawake";
        text = builtins.readFile ./keepawake/keepawake.sh;
      })
    ];
  };
}

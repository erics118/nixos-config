{
  flake.modules.homeManager.darwin = { pkgs, ... }: {
    home.packages = [ pkgs.moonlight-qt ];
  };
}

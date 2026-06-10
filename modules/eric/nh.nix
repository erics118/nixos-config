{
  flake.modules.homeManager.base = { config, ... }: {
    programs.nh = {
      enable = true;
      clean.enable = true;
      clean.extraArgs = "--keep-since 14d --keep 10";
      flake = "${config.home.homeDirectory}/.flake";
    };
  };
}

let
  clean = {
    programs.nh = {
      enable = true;
      clean.enable = true;
      clean.extraArgs = "--keep-since 14d --keep 10 --optimise";
    };
  };
in
{
  flake.modules = {
    # root-level nh clean covers system, per-user, and home-manager generations
    nixos.base = clean;
    darwin.base = clean;

    homeManager.base = { config, ... }: {
      programs.nh = {
        enable = true;
        flake = "${config.home.homeDirectory}/.flake";
      };
    };
  };
}

{
  # agent-aware terminal multiplexer
  flake.modules.homeManager.base = { pkgs, repoFile, ... }: {
    # dtach keeps the scratch popup's shell alive between opens
    home.packages = [
      pkgs.herdr
      pkgs.dtach
    ];

    # config.toml is linked alone, not the whole dir, since herdr keeps its sockets, logs, and sessions in ~/.config/herdr
    home.file.".config/herdr/config.toml".source = repoFile "modules/eric/cli/herdr/config.toml";
    home.file.".config/herdr-automatic-rename/config.sh".source =
      repoFile "modules/eric/cli/herdr/automatic-rename.sh";
  };
}

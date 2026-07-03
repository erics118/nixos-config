{
  flake.modules.homeManager.darwin = { repoFile, ... }: {
    home.file.".config/karabiner.edn".source = repoFile "modules/eric/desktop/karabiner/karabiner.edn";
  };

  flake.modules.darwin.base = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.goku ];

    # re-run goku when karabiner.edn changes
    # launchd.user.agents.goku-watch = {
    #   serviceConfig = {
    #     ProgramArguments = [ (lib.getExe pkgs.goku) ];
    #     WatchPaths = [ "/Users/eric/.config/karabiner.edn" ];
    #     RunAtLoad = true;
    #     KeepAlive = false;
    #     StandardOutPath = "/Users/eric/.local/state/goku.log";
    #     StandardErrorPath = "/Users/eric/.local/state/goku.log";
    #   };
    # };
  };
}

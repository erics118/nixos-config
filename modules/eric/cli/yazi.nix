{
  flake.modules.homeManager.base = { pkgs, repoFileAll, ... }: {
    # linked per file, since programs.yazi.plugins writes into ~/.config/yazi/plugins
    home.file = repoFileAll "modules/eric/cli/yazi" ".config/yazi";

    programs.yazi = {
      enable = true;
      shellWrapperName = "y";
      plugins = {
        inherit (pkgs.yaziPlugins)
          git
          ouch
          piper
          smart-enter
          ;
      };
      # the markdown previewer and the ouch plugin call these from yazi's PATH
      extraPackages = [
        pkgs.glow
        pkgs.ouch
      ];
    };
  };
}

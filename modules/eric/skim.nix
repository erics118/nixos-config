{
  flake.modules.darwin.base = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.skimpdf ];

    # shift-cmd-click inverse search into vimtex
    # an empty preset is skim's custom editor
    system.defaults.CustomUserPreferences."net.sourceforge.skim-app.skim" = {
      SKTeXEditorPreset = "";
      SKTeXEditorCommand = "/etc/profiles/per-user/eric/bin/nvim";
      SKTeXEditorArguments = "--headless -c \"VimtexInverseSearch %line '%file'\"";
      # reload on recompile without asking
      SKAutoReloadFileUpdate = true;
    };
  };
}

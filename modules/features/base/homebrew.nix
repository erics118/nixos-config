{ inputs, ... }: {
  flake.modules.darwin.base = {
    imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

    nix-homebrew = {
      user = "eric";
      enable = true;
      enableRosetta = false;
      autoMigrate = true;
      mutableTaps = true;
      # its eval "$(brew shellenv)" costs a brew process at every shell start
      enableZshIntegration = false;

      # we need to trust taps before we can use them
      trust = {
        formulae = [ ];
        casks = [ ];
        commands = [ ];
        taps = [ ];
      };
    };

    # the output of `brew shellenv`, written out
    # skipped when PATH already starts with brew's dirs, as brew shellenv itself does
    programs.zsh.interactiveShellInit = ''
      if [[ "$PATH:" != /opt/homebrew/bin:/opt/homebrew/sbin:* ]]; then
        export HOMEBREW_PREFIX="/opt/homebrew";
        export HOMEBREW_CELLAR="/opt/homebrew/Cellar";
        export HOMEBREW_REPOSITORY="/opt/homebrew/Library/.homebrew-is-managed-by-nix";
        fpath[1,0]="/opt/homebrew/share/zsh/site-functions";
        export FPATH;
        export PATH="/opt/homebrew/bin:/opt/homebrew/sbin''${PATH+:$PATH}";
        [ -z "''${MANPATH-}" ] || { export MANPATH="''${MANPATH%"''${MANPATH##*[!:]}"}"; export MANPATH=":''${MANPATH#"''${MANPATH%%[!:]*}"}"; };
        export INFOPATH="/opt/homebrew/share/info:''${INFOPATH:-}";
      fi
    '';

    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = false;
        cleanup = "zap"; # or "none"
        upgrade = false;
      };
      global = {
        brewfile = true;
      };

      taps = [ ];

      brews = [
        "openssl"
        "cliclick"
      ];

      casks = [ ];

      masApps = { };
    };
  };
}

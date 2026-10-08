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
        # every activation uninstalls any brew or cask not listed here
        cleanup = "zap";
        upgrade = false;
      };
      global = {
        brewfile = true;
      };

      taps = [ ];

      brews = [
        # jellyfin desktop's bundled libcrypto reads /opt/homebrew/etc/openssl@3/cert.pem
        "openssl"
        # used by hand
        "cliclick"
      ];

      casks = [ ];

      masApps = { };
    };
  };
}

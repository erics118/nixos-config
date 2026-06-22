{ inputs, ... }: {
  flake.modules.darwin.base = { pkgs, ... }: {
    imports = [ inputs.home-manager.darwinModules.home-manager ];

    # spotlight, fseventsd, finder hardening for the /nix volume
    system.activationScripts.postActivation.text = ''
      # disable spotlight
      launchctl unload -w /System/Library/LaunchDaemons/com.apple.metadata.mds.plist >/dev/null 2>&1 || true
      # disable fseventsd on /nix volume
      mkdir -p /nix/.fseventsd
      test -e /nix/.fseventsd/no_log || touch /nix/.fseventsd/no_log
      # tell spotlight never to index /nix
      test -e /nix/.metadata_never_index || touch /nix/.metadata_never_index
      # hide /nix from Finder
      chflags hidden /nix
    '';

    users.users.eric = {
      name = "eric";
      home = "/Users/eric";
      shell = pkgs.zsh;
    };

    nix.settings.trusted-users = [
      "@admin"
      "eric"
    ];

    system = {
      checks.verifyNixPath = false;
      primaryUser = "eric";
      stateVersion = 5;

      defaults = {
        NSGlobalDomain = {
          AppleICUForce24HourTime = true;
          AppleInterfaceStyle = "Dark";
          ApplePressAndHoldEnabled = false;
          AppleScrollerPagingBehavior = true;
          AppleShowAllExtensions = true;
          AppleShowScrollBars = "WhenScrolling";
          AppleTemperatureUnit = "Celsius";
          InitialKeyRepeat = 15;
          KeyRepeat = 1;
          NSAutomaticCapitalizationEnabled = false;
          NSAutomaticDashSubstitutionEnabled = false;
          NSAutomaticInlinePredictionEnabled = false;
          NSAutomaticPeriodSubstitutionEnabled = false;
          NSAutomaticQuoteSubstitutionEnabled = false;
          NSAutomaticSpellingCorrectionEnabled = false;
          "com.apple.keyboard.fnState" = true;
          "com.apple.mouse.tapBehavior" = 1;
          "com.apple.sound.beep.feedback" = 0;
          "com.apple.sound.beep.volume" = 0.0;
          "com.apple.trackpad.forceClick" = true;
        };

        finder = {
          _FXShowPosixPathInTitle = true;
          FXDefaultSearchScope = "SCcf";
          FXEnableExtensionChangeWarning = false;
          FXPreferredViewStyle = "clmv";
          ShowPathbar = true;
          ShowStatusBar = true;
        };

        trackpad = {
          Clicking = true;
          TrackpadThreeFingerDrag = true;
        };

        menuExtraClock = {
          IsAnalog = false;
          Show24Hour = true;
          ShowDayOfWeek = true;
          ShowSeconds = true;
        };

        WindowManager = {
          EnableStandardClickToShowDesktop = false;
          EnableTiledWindowMargins = false;
          GloballyEnabled = false;
          HideDesktop = true;
          StandardHideDesktopIcons = false;
          StandardHideWidgets = false;
        };
      };
    };

    security.pam.services.sudo_local.touchIdAuth = true;
  };
}

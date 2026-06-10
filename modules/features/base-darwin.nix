{ inputs, ... }: {
  flake.modules.darwin.base = { pkgs, ... }: {
    imports = [ inputs.home-manager.darwinModules.home-manager ];

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

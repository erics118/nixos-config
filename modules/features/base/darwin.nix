{ inputs, ... }: {
  flake.modules.darwin.base = { pkgs, ... }: {
    imports = [
      inputs.home-manager.darwinModules.home-manager
      inputs.sops-nix.darwinModules.sops
    ];

    # /nix volume hardening (spotlight, fseventsd, finder), plus disabling duetexpertd
    system.activationScripts.postActivation.text = ''
      # disable fseventsd on /nix volume
      mkdir -p /nix/.fseventsd
      test -e /nix/.fseventsd/no_log || touch /nix/.fseventsd/no_log
      # tell spotlight never to index /nix
      test -e /nix/.metadata_never_index || touch /nix/.metadata_never_index
      # hide /nix from Finder
      chflags hidden /nix
      # disable duetexpertd, app-prediction daemon that pins a cpu core, unused with siri off
      duetuid=$(id -u eric)
      launchctl bootout gui/"$duetuid"/com.apple.duetexpertd 2>/dev/null || true
      launchctl disable gui/"$duetuid"/com.apple.duetexpertd 2>/dev/null || true
    '';

    # skip evaluating the darwin option docs for the html manual and darwin-help
    documentation.doc.enable = false;

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
        CustomUserPreferences = {
          # ignore apple remote desktop (interferes with touch id sudo)
          "com.apple.security.authorization".ignoreArd = true;
          # window corner radius in points, 1 is effectively square corners
          NSGlobalDomain.NSConvolutionOverride1 = 1.0;
          # ask to keep changes when closing documents
          NSGlobalDomain.NSCloseAlwaysConfirmsChanges = true;
          NSGlobalDomain.WebAutomaticSpellingCorrectionEnabled = false;
          # liquid glass tint sliders
          NSGlobalDomain.NSGlassTintAmount = 0.5111468;
          NSGlobalDomain.NSGlassBuddyTintAmount = 0.5;
          # no .DS_Store files on network shares or usb drives
          "com.apple.desktopservices" = {
            DSDontWriteNetworkStores = true;
            DSDontWriteUSBStores = true;
          };
          # modifier held for the bottom-right hot corner
          "com.apple.dock".wvous-br-modifier = 1966080;
          # document icons in window title bars. macos protects this domain, so the
          # write may need full disk access for the activation
          "com.apple.universalaccess".showWindowTitlebarIcons = true;
        };

        NSGlobalDomain = {
          AppleICUForce24HourTime = true;
          AppleIconAppearanceTheme = "RegularDark";
          AppleInterfaceStyle = "Dark";
          ApplePressAndHoldEnabled = false;
          AppleReduceDesktopTinting = true;
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

        dock = {
          autohide = true;
          autohide-delay = 0.5;
          minimize-to-application = true;
          # keep spaces in a fixed order for the tiling wm
          mru-spaces = false;
          show-recents = false;
          showhidden = true;
          tilesize = 50;
          # display sleep
          wvous-br-corner = 10;
          persistent-apps = [
            "/Applications/Fantastical.app"
            "/Applications/Todoist.app"
            "/Applications/Notion.app"
            "/System/Applications/Messages.app"
            "/Applications/Firefox Developer Edition.app"
            "/Applications/Nix Apps/WezTerm.app"
            "/Applications/Slack.app"
            "/Applications/Spotify.app"
          ];
        };

        hitoolbox.AppleFnUsageType = "Do Nothing";

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
          # always, not only when space allows
          ShowDate = 1;
          ShowDayOfWeek = true;
          ShowSeconds = true;
        };

        WindowManager = {
          EnableStandardClickToShowDesktop = false;
          EnableTiledWindowMargins = false;
          # macos's own window tiling off
          EnableTilingByEdgeDrag = false;
          EnableTilingOptionAccelerator = false;
          EnableTopTilingByEdgeDrag = false;
          GloballyEnabled = false;
          HideDesktop = true;
          StandardHideDesktopIcons = false;
          StandardHideWidgets = false;
        };
      };
    };

    # pam_tid.so got renamed to pam_tid.so.2 in macOS 27 Golden Gate
    # nix-darwin has not yet updated to support this, so we have to manually configure it here
    # security.pam.services.sudo_local.touchIdAuth = true;
    security.pam.services.sudo_local.text = ''
      auth sufficient pam_tid.so.2
    '';

    security.sudo.extraConfig = ''
      %admin ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0
    '';
  };
}

{ inputs, ... }:
{
  flake.modules.darwin.base = {
    imports = [
      inputs.home-manager.darwinModules.home-manager
      inputs.nix-homebrew.darwinModules.nix-homebrew
    ];

    nix.settings.trusted-users = [
      "@admin"
      "eric"
    ];

    home-manager.backupFileExtension = "bak";

    nix-homebrew = {
      user = "eric";
      enable = true;
      autoMigrate = true;
    };

    system = {
      checks.verifyNixPath = false;
      primaryUser = "eric";
      stateVersion = 5;

      defaults = {
        NSGlobalDomain = {
          AppleICUForce24HourTime = true;
          AppleInterfaceStyle = "Dark";
          # AppleMiniaturizeOnDoubleClick = false;
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
          ShowStatusBar = false;
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

    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = false;
        cleanup = "none";
        upgrade = false;
      };
      global = {
        brewfile = true;
      };

      taps = [
        "felixkratz/formulae"
        "koekeishiya/formulae"
        # "yqrashawn/goku"
        "supabase/tap"
        "nextdns/tap"
        "charmbracelet/tap"
      ];

      brews = [
        "cmake"
        "gmp"
        "libffi"
        "llvm@19"
        {
          name = "llvm";
          link = true;
        }
        "ltex-ls"
        "lua"
        {
          name = "macos-trash";
          link = true;
        }
        {
          name = "mysql-client";
          link = true;
        }
        "nginx"
        "ninja"
        {
          name = "perl";
          link = false;
        }
        "pipx"
        "pkgconf"
        "prek"
        {
          name = "python@3.13";
          link = false;
        }
        "rsync"
        "serve"
        "spicetify-cli"
        "spotify_player"
        # "vercel-cli"
        "virustotal-cli"
        "watch"
        "charmbracelet/tap/glow"
        "felixkratz/formulae/sketchybar"
        "felixkratz/formulae/svim"
        "koekeishiya/formulae/skhd"
        {
          name = "koekeishiya/formulae/yabai";
          args = [ "HEAD" ];
        }
        "nextdns"
        "supabase"
        # "yqrashawn/goku/goku"
      ];

      casks = [
        "1password"
        "font-sf-pro"
        "font-hack-nerd-font"
        "font-sketchybar-app-font"
        "raycast"
        "espanso"
      ];

      masApps = { };
    };

    security.pam.services.sudo_local.touchIdAuth = true;
  };
}

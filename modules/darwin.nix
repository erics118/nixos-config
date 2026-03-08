{ pkgs, ... }:
{
  nix = {
    settings = {
      trusted-users = [
        "@admin"
        "eric"
      ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
      extra-substituters = [
        "https://nix-community.cachix.org"
        "https://numtide.cachix.org"
      ];
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
      ];
    };
    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 2;
        Minute = 0;
      };
      options = "--delete-older-than 14d";
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    just
  ];

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
        KeyRepeat = 2;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticInlinePredictionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        "com.apple.keyboard.fnState" = true;
        "com.apple.mouse.tapBehavior" = 1;
        "com.apple.sound.beep.feedback" = 0;
        # "com.apple.sound.beep.flash" = 0;
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
    # onActivation.cleanup = "zap";

    taps = [
      "charmbracelet/tap"
      "cloudflare/cloudflare"
      "felixkratz/formulae"
      "koekeishiya/formulae"
      "nextdns/tap"
      "spicetify/tap"
      "supabase/tap"
      "wez/wezterm"
      "ynqa/tap"
      "yqrashawn/goku"
    ];

    brews = [
      #   "grc"
      #   "hcxtools"
      #   "htop"
      #   "http-server"
      #   "jump"
      #   "kakoune"
      #   "less"
      {
        name = "llvm";
        link = true;
      }
      "llvm@19"
      #   "lolcat"
      #   "lsd"
      "ltex-ls"
      "lua"
      #   "lynx"
      {
        name = "macos-trash";
        link = true;
      }
      {
        name = "mysql-client";
        link = true;
      }
      "neofetch"
      "nginx"
      "ninja"
      #   "nowplaying-cli"
      #   "ntfy"
      #   "pcre"
      {
        name = "perl";
        link = false;
      }
      #   "pipes-sh"
      "pipx"
      "pkgconf"
      "prek"
      #   "proselint"
      #   "python-tk@3.14"
      {
        name = "python@3.13";
        link = false;
      }
      #   "railway"
      #   "rmpc"
      "rsync"
      #   "screenresolution"
      "serve"
      "spicetify-cli"
      "spotify_player"
      #   "stylua" # nixpkgs version crashes on darwin; keep here
      #   "swift-format"
      #   "swiftformat"
      #   "switchaudio-osx"
      #   "tccutil"
      #   "tesseract"
      #   "topgrade"
      "vercel-cli"
      "virustotal-cli"
      #   "vscode-langservers-extracted"
      "watch"
      #   "whisper-cpp"
      #   # tap-prefixed formulas
      #   "charmbracelet/tap/charm"
      #   "charmbracelet/tap/confettysh"
      #   "charmbracelet/tap/melt"
      #   "charmbracelet/tap/pop"
      #   "charmbracelet/tap/skate"
      #   "charmbracelet/tap/soft-serve"
      #   "charmbracelet/tap/wishlist"
      #   { name = "felixkratz/formulae/borders"; args = [ "HEAD" ]; }
      "felixkratz/formulae/sketchybar"
      "felixkratz/formulae/svim"
      "koekeishiya/formulae/skhd"
      {
        name = "koekeishiya/formulae/yabai";
        args = [ "HEAD" ];
      }
      "nextdns/tap/nextdns"
    ];

    casks = [
      "1password"
      "font-sf-pro"
      "ghostty"
      "raycast"
    ];

    masApps = { };
  };

  programs.zsh.enable = true;

  security.pam.services.sudo_local.touchIdAuth = true;
}

{ config, ... }:
let
  overlays = builtins.attrValues config.flake.overlays;
  shared =
    { pkgs, ... }:
    {
      nix = {
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          max-jobs = "auto";
          cores = 0;
          warn-dirty = false;
          builders-use-substitutes = true;
          http-connections = 50;
          connect-timeout = 5;
          download-attempts = 3;
          extra-substituters = [
            "https://nix-community.cachix.org"
            "https://numtide.cachix.org"
            "https://devenv.cachix.org"
            "https://cache.numtide.com"
            "https://erics118.cachix.org"
          ];
          extra-trusted-public-keys = [
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
            "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
            "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
            "erics118.cachix.org-1:wJdKw5a7XgwcIJjxKcDHqgTrU6q99hOkOII0Zk+xC1c="
          ];
        };

        gc = {
          automatic = true;
          options = "--delete-older-than 14d";
        };
      };

      programs.zsh = {
        enable = true;
        # home-manager already runs compinit in ~/.config/zsh/.zshrc
        # running it again at the system level doubles startup cost
        enableGlobalCompInit = false;
      };

      nixpkgs = {
        config.allowUnfree = true;
        inherit overlays;
      };

      environment.systemPackages = with pkgs; [
        vim
        wget
        curl
        git
        just
        sops
      ];
    };
in
{
  flake.modules.nixos.base = {
    imports = [ shared ];
    # systemd OnCalendar, sunday 04:00
    nix.gc.dates = "Sun 04:00";
  };
  flake.modules.darwin.base = {
    imports = [ shared ];
    # launchd StartCalendarInterval, sunday 04:00
    nix.gc.interval = {
      Weekday = 0;
      Hour = 4;
      Minute = 0;
    };
  };
}

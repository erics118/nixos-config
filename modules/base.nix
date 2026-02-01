{ inputs, pkgs, ... }:

{
  time.timeZone = "America/New_York";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  nixpkgs.config.allowUnfree = true;

  system = {
    stateVersion = "25.11";
    autoUpgrade = {
      enable = true;
      flake = inputs.self.outPath;
      flags = [
        "-L" # print build logs
      ];
      dates = "weekly";
    };
  };

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
      log-lines = 50;
      auto-optimise-store = true;
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://numtide.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
      ];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    sops
    just
  ];

  environment.pathsToLink = [ "/share/zsh" ];

  networking = {
    networkmanager.enable = true;
    firewall.enable = false;
  };

  programs.zsh.enable = true;
  programs.nix-ld.enable = true;

  security.sudo.wheelNeedsPassword = false;
}

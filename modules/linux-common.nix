{ inputs, pkgs, ... }:

{
  imports = [ ./common.nix ];

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
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

    settings = {
      log-lines = 50;
      auto-optimise-store = true;
    };

    gc = {
      dates = "weekly";
    };
  };

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;

  environment.systemPackages = with pkgs; [
    sops
  ];

  environment.pathsToLink = [ "/share/zsh" ];

  networking = {
    networkmanager.enable = true;
    firewall.enable = false;
  };

  programs.nix-ld.enable = true;

  security.sudo.wheelNeedsPassword = false;
}

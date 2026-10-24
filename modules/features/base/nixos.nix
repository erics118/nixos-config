{ inputs, ... }: {
  flake.modules.nixos.base = { config, pkgs, ... }: {
    imports = [
      inputs.catppuccin.nixosModules.catppuccin
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
    ];

    catppuccin = {
      # same reason as catppuccin.sources in hm.nix
      sources = (import "${inputs.catppuccin}/default.nix" { inherit pkgs; }).packages;
      enable = true;
      autoEnable = false;
      tty.enable = true;
    };

    nix = {
      settings = {
        log-lines = 50;
        trusted-users = [ "eric" ];
      };
    };

    # skip evaluating the nixos option docs for the manual and nixos-help
    documentation.nixos.enable = false;

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

    system.stateVersion = "25.11";

    boot.tmp.cleanOnBoot = true;
    zramSwap.enable = true;

    fonts.packages = [ pkgs.nerd-fonts.hack ];

    environment.systemPackages = with pkgs; [
      # build tools
      gcc
      gnumake
      pkg-config

      # archives and file inspection
      file
      unzip
      zip

      # host inspection
      lsof
      openssl
      pciutils
      usbutils
      dnsutils
    ];

    environment.pathsToLink = [ "/share/zsh" ];

    networking = {
      networkmanager.enable = true;
      firewall.enable = true;
    };

    programs.nix-ld.enable = true;

    # nix-index in hm.nix handles unknown commands
    # the channel tarball ships programs.sqlite, which would turn this on by default
    programs.command-not-found.enable = false;

    security.sudo.wheelNeedsPassword = false;

    # a yescrypt hash from `mkpasswd`, decrypted before users are created
    sops.secrets."eric/password".neededForUsers = true;

    users.users.eric = {
      isNormalUser = true;
      # nixos-anywhere --chown and auto-upgrade's SUDO_UID both use 1000
      uid = 1000;
      description = "eric";
      # with mutableUsers this only applies when the user is first created, so a fresh install has a console login
      hashedPasswordFile = config.sops.secrets."eric/password".path;
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      shell = pkgs.zsh;

      # each machine's own ~/.ssh/id_ed25519
      # turtle's is left out because it is public-facing, so it can't log in to the others
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKYegGpRKtmZCW3UNYOym55wAyRqi2JiVLgUUmbiWCf1 eric@orca"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBIaXnl7v3GUEMwnWD2O829pBZRWxQwi6feMGve3usbl eric@narwhal"
      ];
    };

  };
}

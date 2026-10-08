{ inputs, ... }: {
  flake.modules.nixos.base = { pkgs, ... }: {
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

    environment.pathsToLink = [ "/share/zsh" ];

    networking = {
      networkmanager.enable = true;
      firewall.enable = true;
    };

    programs.nix-ld.enable = true;

    security.sudo.wheelNeedsPassword = false;

    users.users.eric = {
      isNormalUser = true;
      description = "eric";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      shell = pkgs.zsh;

      # shared base key: ~/.ssh/id_ed25519 on orca
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKYegGpRKtmZCW3UNYOym55wAyRqi2JiVLgUUmbiWCf1 eric@orca"
      ];
    };

  };
}

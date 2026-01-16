{
  imports = [
    ./hardware/vm-aarch64-prl.nix
    ../modules/base.nix
    ../modules/desktop-gnome.nix
    ../modules/users-eric.nix
    # ../modules/ros-kilted.nix
    ../modules/ssh.nix
    ../modules/rust.nix
    ../modules/sops.nix
  ];

  networking.hostName = "nixos-vm";

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  hardware.parallels.enable = true;

  systemd.user.services.prlcc.enable = false;

  services.tailscale.enable = true;

  virtualisation.docker = {
    enable = true;
  };
}

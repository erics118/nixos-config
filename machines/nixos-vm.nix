{
  imports = [
    ./hardware/vm-aarch64-prl.nix
    ../modules/linux-common.nix
    ../modules/desktop-gnome.nix
    ../modules/users-eric.nix
    ../modules/ros-kilted.nix
    ../modules/ssh.nix
    ../modules/sops.nix
    ../modules/tailscale.nix
  ];

  # modules.ros-kilted.enable = true;

  networking.hostName = "nixos-vm";

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  hardware.parallels.enable = true;

  systemd.user.services.prlcc.enable = false;
}

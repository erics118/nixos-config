{
  imports = [
    ./hardware/vm-aarch64-prl.nix
  ];

  # modules.ros-kilted.enable = true;

  home-manager.users.eric.imports = [ ../users/eric/gui-linux.nix ];

  networking.hostName = "nixos-vm";

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  hardware.parallels.enable = true;

  systemd.user.services.prlcc.enable = false;
}

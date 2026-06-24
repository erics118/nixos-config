{
  flake.modules.nixos.nvidia = { pkgs, ... }: {
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.graphics = {
      enable = true;
      extraPackages = [ pkgs.nvidia-vaapi-driver ];
    };

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      open = true;
      nvidiaSettings = true;
    };

    hardware.nvidia-container-toolkit.enable = true;

    # CUDA binary cache
    nix.settings = {
      extra-substituters = [ "https://cache.nixos-cuda.org" ];
      extra-trusted-public-keys = [ "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=" ];
    };
  };
}

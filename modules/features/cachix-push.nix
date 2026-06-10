{
  flake.modules.nixos.cachix-push = { pkgs, ... }: {
    # auto-push on successful builds to cachix
    # configure cachix with: cachix authtoken <TOKEN>
    nix.settings.post-build-hook = pkgs.writeShellScript "upload-to-cachix" ''
      set -eu
      set -f
      export IFS=' '
      export PATH=${pkgs.cachix}/bin:${pkgs.openssh}/bin:$PATH
      exec cachix push erics118 $OUT_PATHS
    '';

    environment.systemPackages = [ pkgs.cachix ];
  };
}

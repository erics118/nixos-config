let
  body =
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

      environment.systemPackages = with pkgs; [
        vim
        wget
        curl
        git
        just
      ];

      programs.zsh.enable = true;
    };
in
{
  flake.modules.nixos.common-nix = body;
  flake.modules.darwin.common-nix = body;
}

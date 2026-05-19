{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem = _: {
    treefmt = {
      projectRootFile = "flake.nix";

      settings.excludes = [
        "secrets/**"
      ];

      programs.nixfmt.enable = true;
      programs.deadnix.enable = true;
      programs.statix.enable = true;
      programs.prettier.enable = true;
      programs.shfmt.enable = true;
      programs.shellcheck.enable = true;
      programs.just.enable = true;
      programs.taplo.enable = true;
    };
  };
}

{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem = _: {
    treefmt = {
      projectRootFile = "flake.nix";

      settings.excludes = [
        "secrets/**"
      ];

      programs = {
        nixfmt.enable = true;
        deadnix.enable = true;
        statix.enable = true;
        prettier.enable = true;
        shfmt.enable = true;
        shellcheck.enable = true;
        just.enable = true;
        taplo.enable = true;
      };
    };
  };
}

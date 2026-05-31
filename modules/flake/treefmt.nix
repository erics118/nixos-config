{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem = _: {
    treefmt = {
      projectRootFile = "flake.nix";

      settings = {
        excludes = [
          "secrets/**"
          "result"
          "result-*"
          "flake.lock"
          "*.age"
        ];
        on-unmatched = "info";
        formatter.stylua.options = [
          "--indent-type"
          "Spaces"
          "--indent-width"
          "4"
        ];
      };

      programs = {
        # nix
        nixfmt.enable = true;
        nixfmt.strict = true;
        deadnix.enable = true;
        statix.enable = true;

        shfmt.enable = true;
        shellcheck.enable = true;

        prettier.enable = true;
        just.enable = true;
        taplo.enable = true;
        yamlfmt = {
          enable = true;
          settings.formatter.retain_line_breaks_single = true;
        };
        jsonfmt.enable = true;

        stylua.enable = true;
        clang-format.enable = true;
      };
    };
  };
}

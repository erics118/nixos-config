{ inputs, ... }: {
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
        # stylua config (indent type/width) lives in stylua.toml
      };

      programs = {
        # nix
        nixfmt.enable = true;
        nixfmt.strict = true;
        deadnix.enable = true;
        statix.enable = true;

        shfmt.enable = true;

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

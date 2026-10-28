{
  perSystem = { pkgs, ... }: {
    treefmt = {
      projectRootFile = "flake.nix";

      settings = {
        excludes = [
          "result"
          "result-*"
          "flake.lock"
        ];
        on-unmatched = "info";

        # depth 1 because deeper follows pull pinned inputs off their own nixpkgs
        # no lock because the check runs in the sandbox with no network
        formatter.flake-edit = {
          command = pkgs.flake-edit;
          options = [
            "--non-interactive"
            "--no-lock"
            "follow"
            "--depth"
            "1"
          ];
          includes = [ "flake.nix" ];
        };
      };

      programs = {
        nixfmt.enable = true;
        nixfmt.strict = true;
        deadnix.enable = true;
        statix.enable = true;

        shfmt.enable = true;
        shellcheck = {
          enable = true;
          # direnv syntax, no shebang
          excludes = [ ".envrc" ];
        };

        prettier = {
          enable = true;
          # rex skill status compares the stub byte for byte with what rex skill setup writes
          # jsonfmt owns json, in the expanded layout claude code writes settings.json in
          excludes = [
            "modules/eric/ai/skills/shared/rex/SKILL.md"
            "*.json"
          ];
        };
        just.enable = true;
        taplo.enable = true;
        yamlfmt = {
          enable = true;
          settings.formatter.retain_line_breaks_single = true;
        };
        jsonfmt.enable = true;

        actionlint.enable = true;
        zizmor.enable = true;

        # settings live in stylua.toml
        stylua.enable = true;
        clang-format.enable = true;
        gofmt.enable = true;
      };
    };
  };
}

{
  flake.modules.homeManager.base =
    {
      repoFile,
      lib,
      pkgs,
      ...
    }:
    let
      base = "modules/eric/ai";
      vendors = {
        claude = "claude";
        codex = "codex";
      };
      skillLocations = {
        agents = ".agents/skills";
        claude = ".claude/skills";
      };
      vendorFiles =
        vendor: files:
        lib.mapAttrs' (
          target: source:
          lib.nameValuePair ".${vendor}/${target}" { source = repoFile "${base}/${vendor}/${source}"; }
        ) files;
      skillDirectories =
        location: scope:
        let
          skills = ./ai/skills + "/${scope}";
          names = builtins.attrNames (
            lib.filterAttrs (_: type: type == "directory") (builtins.readDir skills)
          );
        in
        lib.listToAttrs (
          map (
            name:
            lib.nameValuePair "${location}/${name}" { source = repoFile "${base}/skills/${scope}/${name}"; }
          ) names
        );
      context7Mcp = pkgs.writeShellApplication {
        name = "context7-mcp";
        runtimeInputs = [ pkgs.nodejs ];
        text = ''
          KEY_FILE=/run/secrets/api/context7
          CONTEXT7_API_KEY="''${CONTEXT7_API_KEY:-}"
          if [[ -z $CONTEXT7_API_KEY && -r $KEY_FILE ]]; then
            CONTEXT7_API_KEY="$(<"$KEY_FILE")"
          fi
          if [[ -z $CONTEXT7_API_KEY ]]; then
            printf >&2 'context7-mcp: no api key. export CONTEXT7_API_KEY or provision %s\n' "$KEY_FILE"
            exit 1
          fi
          export CONTEXT7_API_KEY
          npm_config_cache="''${XDG_CACHE_HOME:-$HOME/.cache}/context7/npm"
          export npm_config_cache

          exec npx --yes @upstash/context7-mcp@4.0.2
        '';
      };
    in
    {
      home.file =
        vendorFiles vendors.codex {
          "AGENTS.md" = "AGENTS.md";
          "config.toml" = "config.toml";
          "hooks.json" = "hooks.json";
          "rules/default.rules" = "rules/default.rules";
        }
        // vendorFiles vendors.claude {
          "CLAUDE.md" = "CLAUDE-global.md";
          "settings.json" = "settings.json";
          "statusline.sh" = "statusline.sh";
          hooks = "hooks";
          rules = "rules";
        }
        // skillDirectories skillLocations.agents "shared"
        // skillDirectories skillLocations.agents vendors.codex
        // skillDirectories skillLocations.claude "shared"
        // skillDirectories skillLocations.claude vendors.claude;

      home.activation.migrateClaudeSkills =
        lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
          ''
            skills="$HOME/.claude/skills"

            if test -L "$skills" && ! test -e "$skills"; then
              target="$(${pkgs.coreutils}/bin/readlink "$skills")"

              case "$target" in
                /nix/store/*-home-manager-files/.claude/skills)
                  verboseEcho "Removing obsolete Home Manager link at $skills"
                  $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm "$skills"
                  ;;
                *)
                  errorEcho "$skills is a dangling symlink not created by the previous Home Manager layout"
                  exit 1
                  ;;
              esac
            elif test -e "$skills" && ! test -d "$skills"; then
              errorEcho "$skills exists but is not a directory"
              exit 1
            fi
          '';

      home.packages = with pkgs; [
        ccusage
        context7Mcp
      ];
    };
}

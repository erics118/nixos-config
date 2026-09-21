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
        }
        // skillDirectories skillLocations.agents "shared"
        // skillDirectories skillLocations.agents vendors.codex
        // skillDirectories skillLocations.claude "shared"
        // skillDirectories skillLocations.claude vendors.claude;

      home.packages = with pkgs; [
        ccusage
        context7Mcp
      ];
    };
}

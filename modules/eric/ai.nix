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
      globalInstructions = repoFile "${base}/AGENTS.md";
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
          # nix node trusts only NIX_SSL_CERT_FILE, which codex strips from mcp servers
          export NIX_SSL_CERT_FILE="''${NIX_SSL_CERT_FILE:-/etc/ssl/certs/ca-certificates.crt}"

          exec npx --yes @upstash/context7-mcp@4.0.2
        '';
      };
      cornellConfluenceMcp = pkgs.writeShellApplication {
        name = "cornell-confluence-mcp";
        runtimeInputs = [ pkgs.uv ];
        text = ''
          KEY_FILE=/run/secrets/api/cornell-confluence
          CONFLUENCE_PERSONAL_TOKEN="''${CONFLUENCE_PERSONAL_TOKEN:-}"
          if [[ -z $CONFLUENCE_PERSONAL_TOKEN && -r $KEY_FILE ]]; then
            CONFLUENCE_PERSONAL_TOKEN="$(<"$KEY_FILE")"
          fi
          if [[ -z $CONFLUENCE_PERSONAL_TOKEN ]]; then
            printf >&2 'cornell-confluence-mcp: no token. export CONFLUENCE_PERSONAL_TOKEN or provision %s\n' "$KEY_FILE"
            exit 1
          fi
          export CONFLUENCE_PERSONAL_TOKEN
          export CONFLUENCE_URL=https://confluence.cornell.edu

          exec uvx mcp-atlassian@0.23.1
        '';
      };
    in
    {
      home.file = {
        ".claude/CLAUDE.md".source = globalInstructions;
        ".codex/AGENTS.md".source = globalInstructions;
        ".agents/hooks".source = repoFile "${base}/hooks";
      }
      // vendorFiles vendors.codex {
        "config.toml" = "config.toml";
        "hooks.json" = "hooks.json";
        "rules/default.rules" = "rules/default.rules";
      }
      // vendorFiles vendors.claude {
        "settings.json" = "settings.json";
        "statusline.sh" = "statusline.sh";
      }
      // skillDirectories skillLocations.agents "shared"
      // skillDirectories skillLocations.agents vendors.codex
      // skillDirectories skillLocations.claude "shared"
      // skillDirectories skillLocations.claude vendors.claude;

      home.packages = with pkgs; [
        ccusage
        context7Mcp
        cornellConfluenceMcp
      ];
    };
}

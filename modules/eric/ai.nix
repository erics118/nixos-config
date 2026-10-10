{
  flake.modules.homeManager.base =
    {
      repoFile,
      repoFileAll,
      lib,
      pkgs,
      ...
    }:
    let
      base = "modules/eric/ai";
      globalInstructions = repoFile "${base}/AGENTS.md";
      # links each named path under ~/<target> to the same path under <base>/<source>
      links =
        target: source: names:
        lib.genAttrs' names (
          name: lib.nameValuePair "${target}/${name}" { source = repoFile "${base}/${source}/${name}"; }
        );
      # links every skill directory in <base>/skills/<scope> into ~/<target>
      skillDirectories =
        target: scope:
        links target "skills/${scope}" (
          builtins.attrNames (
            lib.filterAttrs (_: type: type == "directory") (builtins.readDir (./ai/skills + "/${scope}"))
          )
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
        ".pi/agent/AGENTS.md".source = globalInstructions;
        ".agents/hooks".source = repoFile "${base}/hooks";
      }
      // links ".claude" "claude" [
        "agents"
        "keybindings.json"
        "settings.json"
        "statusline.sh"
      ]
      // links ".codex" "codex" [
        "agents"
        "config.toml"
        "hooks.json"
        "rules/default.rules"
      ]
      // links ".pi/agent" "pi" [
        "agents"
        "settings.json"
        "hermes-memory-config.json"
        "APPEND_SYSTEM.md"
        "mcp.json"
      ]
      // repoFileAll "${base}/pi/extensions" ".pi/agent/extensions"
      // repoFileAll "${base}/pi/lib" ".pi/agent/lib"
      // repoFileAll "${base}/pi/themes" ".pi/agent/themes"
      # claude reads ~/.claude/skills, codex and pi read ~/.agents/skills
      // skillDirectories ".claude/skills" "shared"
      // skillDirectories ".claude/skills" "claude"
      // skillDirectories ".agents/skills" "shared"
      // skillDirectories ".agents/skills" "codex";

      # pi's default agent dir, set explicitly so pi-subagents saves new agents to the
      # repo-linked ~/.pi/agent/agents instead of ~/.agents, which it picks whenever that exists
      home.sessionVariables.PI_CODING_AGENT_DIR = "$HOME/.pi/agent";
      # pi's better-sqlite3 runs node-gyp on install
      # gyp needs ctypes, which python3Minimal lacks
      home.sessionVariables.npm_config_python = lib.getExe pkgs.python3;

      # agent shells pass unmatched globs and words starting with = through like bash
      programs.zsh.envExtra = ''
        [[ -n ''${CLAUDECODE-} || -n ''${CODEX_SHELL-} ]] && setopt no_nomatch no_equals
      '';

      home.packages = with pkgs; [
        ccusage
        context7Mcp
        cornellConfluenceMcp
      ];
    };
}

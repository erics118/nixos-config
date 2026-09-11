{
  flake.modules.homeManager.base =
    { repoFile, ... }:
    let
      base = "modules/eric/ai/pi";
    in
    {
      home.file = {
        ".pi/agent/settings.json".source = repoFile "${base}/settings.json";
        ".pi/agent/auth.json".source = repoFile "${base}/auth.json";
        ".pi/agent/APPEND_SYSTEM.md".source = repoFile "${base}/APPEND_SYSTEM.md";
        ".pi/agent/AGENTS.md".source = repoFile "${base}/AGENTS.md";
        ".pi/agent/extensions/claude-statusline.ts".source = repoFile "${base}/extensions/claude-statusline.ts";
        # pi-mcp-adapter reads ~/.config/mcp/mcp.json (highest precedence)
        ".config/mcp/mcp.json".source = repoFile "${base}/mcp.json";
      };

      # nix owns the binary lifecycle; stop the update-check nag
      home.sessionVariables.PI_SKIP_VERSION_CHECK = "1";
    };
}

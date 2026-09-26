{
  flake.modules.homeManager.base =
    { repoFile, repoFileAll, ... }:
    let
      base = "modules/eric/ai/pi";
    in
    {
      home.file = {
        ".pi/agent/settings.json".source = repoFile "${base}/settings.json";
        ".pi/agent/auth.json".source = repoFile "${base}/auth.json";
        ".pi/agent/hermes-memory-config.json".source = repoFile "${base}/hermes-memory-config.json";
        ".pi/agent/APPEND_SYSTEM.md".source = repoFile "${base}/APPEND_SYSTEM.md";
        ".pi/agent/AGENTS.md".source = repoFile "${base}/AGENTS.md";
        ".pi/agent/packages/pi-diff".source = repoFile "${base}/packages/pi-diff";
        # pi-mcp-adapter reads ~/.config/mcp/mcp.json (highest precedence)
        ".config/mcp/mcp.json".source = repoFile "${base}/mcp.json";
      }
      // repoFileAll "${base}/extensions" ".pi/agent/extensions"
      // repoFileAll "${base}/lib" ".pi/agent/lib"
      // repoFileAll "${base}/themes" ".pi/agent/themes"
      // repoFileAll "${base}/packages/pi-web-activation" ".pi/agent/packages/pi-web-activation"
      // repoFileAll "${base}/packages/pi-eric-memory" ".pi/agent/packages/pi-eric-memory";

      # nix owns the binary lifecycle; stop the update-check nag
      home.sessionVariables.PI_SKIP_VERSION_CHECK = "1";
    };
}

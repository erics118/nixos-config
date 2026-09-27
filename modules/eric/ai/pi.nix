{
  flake.modules.homeManager.base =
    {
      pkgs,
      lib,
      repoFile,
      repoFileAll,
      ...
    }:
    let
      base = "modules/eric/ai/pi";
    in
    {
      home.file = {
        ".pi/agent/settings.json".source = repoFile "${base}/settings.json";
        ".pi/agent/hermes-memory-config.json".source = repoFile "${base}/hermes-memory-config.json";
        ".pi/agent/APPEND_SYSTEM.md".source = repoFile "${base}/APPEND_SYSTEM.md";
        ".pi/agent/AGENTS.md".source = repoFile "modules/eric/ai/AGENTS.md";
        # pi-mcp-adapter reads ~/.config/mcp/mcp.json (highest precedence)
        ".config/mcp/mcp.json".source = repoFile "${base}/mcp.json";
      }
      // repoFileAll "${base}/extensions" ".pi/agent/extensions"
      // repoFileAll "${base}/lib" ".pi/agent/lib"
      // repoFileAll "${base}/themes" ".pi/agent/themes"
      // repoFileAll "${base}/packages/pi-web-activation" ".pi/agent/packages/pi-web-activation";

      # nix owns the binary lifecycle; stop the update-check nag
      home.sessionVariables.PI_SKIP_VERSION_CHECK = "1";

      # better-sqlite3 runs node-gyp on install
      # gyp needs ctypes, which python3Minimal lacks
      home.sessionVariables.npm_config_python = lib.getExe pkgs.python3;
    };
}

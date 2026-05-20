{
  flake.modules.homeManager.base =
    { repoFile, ... }:

    {
      home.file.".claude/statusline-command.sh".source =
        repoFile "modules/eric/cli/files/statusline-command.sh";

      # live-symlink so edits to claude-settings.json take effect without a rebuild
      home.file.".claude/settings.json".source = repoFile "modules/eric/cli/files/claude-settings.json";

      programs.claude-code = {
        enable = true;

        # settings is unset so we can use a symlink

        # mcpServers.nia = {
        #   type = "http";
        #   url = "https://apigcp.trynia.ai/mcp";
        #   headers.Authorization = "Bearer \${NIA_API_KEY}";
        # };

        # agents.nia = builtins.readFile (inputs.nia-rules + "/.claude/agents/nia.md");
        # skills.nia = "${inputs.nia-rules}/.claude/skills/nia";
      };
    };
}

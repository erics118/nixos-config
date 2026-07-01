{
  flake.modules.homeManager.base =
    { repoFileAll, pkgs, ... }:
    let
      llm-agents = pkgs.inputs.llm-agents;
    in
    {
      home.file = repoFileAll "modules/eric/cli/files/claude" ".claude";

      programs.claude-code = {
        enable = true;
        package = llm-agents.claude-code;

        # settings is unset so we can use a symlink
      };

      programs.codex = {
        enable = true;
        package = llm-agents.codex;
      };

      programs.antigravity-cli = {
        enable = true;
        package = llm-agents.antigravity-cli;
      };

      programs.github-copilot-cli = {
        enable = true;
        package = llm-agents.copilot-cli;
      };

      programs.opencode = {
        enable = true;
        package = llm-agents.opencode;
      };

      home.packages = with llm-agents; [
        agentsview
        herdr
        skills
        ccusage
        codegraph
      ];
    };
}

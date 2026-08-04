{
  flake.modules.homeManager.base =
    { repoFile, pkgs, ... }:
    let
      llm-agents = pkgs.inputs.llm-agents;
      base = "modules/eric/cli/claude";
    in
    {
      home.file.".claude/CLAUDE.md".source = repoFile "${base}/CLAUDE.md";
      home.file.".claude/settings.json".source = repoFile "${base}/settings.json";
      home.file.".claude/statusline.sh".source = repoFile "${base}/statusline.sh";
      home.file.".claude/hooks".source = repoFile "${base}/hooks";
      home.file.".claude/rules".source = repoFile "${base}/rules";
      home.file.".claude/skills".source = repoFile "${base}/skills";

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

      home.packages = with llm-agents; [
        agentsview
        herdr
        skills
        ccusage
      ];
    };
}

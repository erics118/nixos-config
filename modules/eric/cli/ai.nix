{
  flake.modules.homeManager.base = { repoFile, pkgs, ... }: {
    home.file.".claude/statusline-command.sh".source =
      repoFile "modules/eric/cli/files/claude-statusline-command.sh";

    # live-symlink so edits to claude-settings.json take effect without a rebuild
    home.file.".claude/settings.json".source = repoFile "modules/eric/cli/files/claude-settings.json";
    home.file.".claude/CLAUDE.md".source = repoFile "modules/eric/cli/files/CLAUDE.md";

    programs.claude-code = {
      enable = true;
      package = pkgs.inputs.llm-agents.claude-code;

      # settings is unset so we can use a symlink
    };

    programs.codex = {
      enable = true;
      package = pkgs.inputs.llm-agents.codex;
    };

    programs.antigravity-cli = {
      enable = true;
      package = pkgs.inputs.llm-agents.antigravity-cli;
    };

    programs.github-copilot-cli = {
      enable = true;
      package = pkgs.inputs.llm-agents.copilot-cli;
    };

    programs.opencode = {
      enable = true;
      package = pkgs.inputs.llm-agents.opencode;
    };

    home.packages = [ pkgs.inputs.llm-agents.skills ];
  };
}

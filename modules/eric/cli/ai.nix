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
      };

      programs.codex.enable = true;

      programs.antigravity-cli.enable = true;

      programs.github-copilot-cli.enable = true;

      programs.opencode.enable = true;
    };
}

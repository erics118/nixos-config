{
  flake.modules.homeManager.base =
    { repoFile, pkgs, ... }:
    let
      base = "modules/eric/cli/claude";
    in
    {
      home.file.".claude/CLAUDE.md".source = repoFile "${base}/CLAUDE-global.md";
      home.file.".claude/settings.json".source = repoFile "${base}/settings.json";
      home.file.".claude/statusline.sh".source = repoFile "${base}/statusline.sh";
      home.file.".claude/hooks".source = repoFile "${base}/hooks";
      home.file.".claude/rules".source = repoFile "${base}/rules";
      home.file.".claude/skills".source = repoFile "${base}/skills";

      home.packages = with pkgs; [ ccusage ];
    };
}

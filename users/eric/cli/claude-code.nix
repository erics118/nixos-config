{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:

{
  home.file.".claude/statusline-command.sh" = {
    source = ./statusline-command.sh;
    executable = true;
  };

  programs.claude-code = {
    enable = true;
    package = pkgs.inputs.llm-agents.claude-code;

    # settings intentionally left unset so the HM module does not symlink
    # ~/.claude/settings.json to a read-only /nix/store path. We install a
    # writable copy via home.activation below from ./claude-settings.json
    # so local edits are possible (overwritten on the next home-manager switch).

    mcpServers.nia = {
      type = "http";
      url = "https://apigcp.trynia.ai/mcp";
      headers.Authorization = "Bearer \${NIA_API_KEY}";
    };

    agents.nia = builtins.readFile (inputs.nia-rules + "/.claude/agents/nia.md");
    skills.nia = "${inputs.nia-rules}/.claude/skills/nia";
  };

  home.activation.installClaudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -L "${config.home.homeDirectory}/.claude/settings.json" ]; then
      run rm "${config.home.homeDirectory}/.claude/settings.json"
    fi
    run install -D -m 644 ${./claude-settings.json} "${config.home.homeDirectory}/.claude/settings.json"
  '';
}

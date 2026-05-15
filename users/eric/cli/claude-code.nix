{ inputs, ... }:

{
  home.file.".claude/statusline-command.sh" = {
    source = ./statusline-command.sh;
    executable = true;
  };

  programs.claude-code = {
    enable = true;

    settings = {
      permissions = {
        allow = [
          "Bash(cat *)"
          "Bash(cut *)"
          "Bash(df *)"
          "Bash(du *)"
          "Bash(dune:*)"
          "Bash(fd *)"
          "Bash(file *)"
          "Bash(find:*)"
          "Bash(git diff *)"
          "Bash(git log *)"
          "Bash(git show *)"
          "Bash(git status *)"
          "Bash(grep *)"
          "Bash(head *)"
          "Bash(jq *)"
          "Bash(less *)"
          "Bash(ls *)"
          "Bash(nix develop:*)"
          "Bash(ocamlfind:*)"
          "Bash(ocamlmerlin:*)"
          "Bash(pwd *)"
          "Bash(rg *)"
          "Bash(scc *)"
          "Bash(sort *)"
          "Bash(stat *)"
          "Bash(tail *)"
          "Bash(tr *)"
          "Bash(tree *)"
          "Bash(uniq *)"
          "Bash(wc *)"
          "Bash(which:*)"
          "Bash(xargs cat *)"
          "Bash(xargs ls *)"
          "Bash(npm run build:*)"
          "Bash(npm run dev:*)"
          "Bash(npm run start:*)"
          "mcp__ide__getDiagnostics"
          "mcp__context7__"
          "mcp__apigcp__"
          "Skill(nia)"
        ];
      };

      statusLine = {
        type = "command";
        command = "bash ~/.claude/statusline-command.sh";
      };

      enabledPlugins = {
        "feature-dev@claude-plugins-official" = true;
        "codebase-cleanup@claude-code-workflows" = false;
        "code-refactoring@claude-code-workflows" = true;
        "frontend-design@claude-plugins-official" = true;
        "typescript-lsp@claude-plugins-official" = false;
        "claude-code-setup@claude-plugins-official" = true;
        "code-review@claude-plugins-official" = false;
        "superpowers@claude-plugins-official" = true;
        "code-simplifier@claude-plugins-official" = true;
        "rust-analyzer-lsp@claude-plugins-official" = false;
        "clangd-lsp@claude-plugins-official" = false;
        "pyright-lsp@claude-plugins-official" = false;
        "agent-orchestration@claude-code-workflows" = true;
        "cicd-automation@claude-code-workflows" = false;
        "ralph-loop@claude-plugins-official" = true;
        "context7@claude-plugins-official" = true;
        "swift-lsp@claude-plugins-official" = false;
        "claude-md-management@claude-plugins-official" = true;
        "impeccable@impeccable" = false;
        "skill-creator@claude-plugins-official" = false;
        "hookify@claude-plugins-official" = true;
      };

      extraKnownMarketplaces = {
        impeccable = {
          source = {
            source = "github";
            repo = "pbakaus/impeccable";
          };
        };
        metal-lsp = {
          source = {
            source = "github";
            repo = "rayanht/metal-lsp";
          };
        };
      };

      skipDangerousModePermissionPrompt = true;
      verbose = true;
      model = "opus";
    };

    mcpServers.nia = {
      type = "http";
      url = "https://apigcp.trynia.ai/mcp";
      headers.Authorization = "Bearer \${NIA_API_KEY}";
    };

    agents.nia = builtins.readFile (inputs.nia-rules + "/.claude/agents/nia.md");
    skills.nia = "${inputs.nia-rules}/.claude/skills/nia";
  };
}

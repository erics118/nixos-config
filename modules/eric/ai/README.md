# Agent stack

Claude Code, Codex, and pi share one instruction file and one set of skills.

- `AGENTS.md` is linked as `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, and `~/.pi/agent/AGENTS.md`. pi-only rules live in `pi/APPEND_SYSTEM.md`.
- `skills/shared/` goes to `~/.claude/skills` and `~/.agents/skills` (Codex and pi). `skills/claude/` is Claude-only. `skills/codex/` also goes to `~/.agents/skills`, so Codex and pi both get it.
- Guard hooks live in `hooks/`, linked as `~/.agents/hooks`. `claude/settings.json` is the one list of which hook runs for which tool: Claude runs it, and pi's `pi/extensions/guards.ts` reads the same file. Codex runs the shell-command guards listed in `codex/hooks.json` (trust them once with `/hooks`).

## When to invoke what

Invoke with `/name` in Claude Code, `$name` in Codex, and `/skill:name` in pi.

| Moment                                         | Skill                                                                            |
| ---------------------------------------------- | -------------------------------------------------------------------------------- |
| Small, clear change                            | none                                                                             |
| A question where an edit would be wrong        | `ask`                                                                            |
| Which mechanism or design should do a job      | `redesign`                                                                       |
| Doubt a claim before acting on it              | `recheck`                                                                        |
| Many files, or code plus docs plus CI          | `writing-plans`, then `executing-plans` (or `executing-plans-agentic` in Claude) |
| Before committing                              | `summarize-changes`                                                              |
| Review                                         | `audit`, or `adversarial-review`                                                 |
| An agent failed and it should not happen again | `fix-yourself`                                                                   |

These load on their own when they apply: `rewrite` (cutting or restructuring prose), `recall` (past sessions), `grilling`, `systematic-debugging`, `test-driven-development`.

## Guards

All of these run in Claude and pi. Codex runs the shell-command guards except `strip-claude-attribution.sh` and `ask-dangerous-git.sh`: Codex has no "ask" decision, so `codex/rules/default.rules` prompts before those git commands instead.

Before a shell command:

- `git-add-before-nix.sh`: no flake evaluation while new `.nix` files are untracked
- `strip-claude-attribution.sh`: removes Claude attribution from commit and PR messages
- `block-global-find.sh`: no `find` rooted at `/`, `~`, or `/nix`
- `block-symlink-clobber.sh`: no mv, cp, tee, or redirect over a managed symlink
- `ask-dangerous-git.sh`: asks before push, rebase, reset, clean, and other history or remote changes
- `block-agent-commit.sh`: agents commit only where `git config agent.autonomous true` is set, and only the user sets it
- `block-shell-edit.sh`: no sed/perl in place, scripts that write, or redirects onto git-tracked files
- `block-sudo-probe.sh`: no `sudo -n` on macOS, where Touch ID approves a plain `sudo`

Before a file read or edit: `deny-symlink-path.sh` (use the real path, not a managed symlink), `block-smart-punct.sh` (no em dashes or curly quotes), `block-write-tracked.sh` (no whole-file Write over a git-tracked file).

After an edit: `treefmt-on-edit.sh` (formats the file), `warn-comment-block.sh` (flags comment blocks of four or more lines).

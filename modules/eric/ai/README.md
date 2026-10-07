# Agent stack

Claude Code, Codex, and pi share one instruction file and one set of skills.

- `AGENTS.md` is linked as `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, and `~/.pi/agent/AGENTS.md`. pi-only rules live in `pi/APPEND_SYSTEM.md`.
- `skills/shared/` goes to `~/.claude/skills` and `~/.agents/skills` (Codex and pi). `skills/claude/` is Claude-only. `skills/codex/` also goes to `~/.agents/skills`, so Codex and pi both get it.
- Subagents live in `claude/agents/`, `codex/agents/`, and `pi/agents/`, linked as `~/.claude/agents`, `~/.codex/agents`, and `~/.pi/agent/agents`. Each tool has `auditor` and `recall`. Claude and Codex also have `researcher`, and pi uses its built-in one. Codex agents cannot be made read-only, so read-only is only an instruction there.
- Guard hooks live in `hooks/`, linked as `~/.agents/hooks`. `claude/settings.json` is the one list of which hook runs for which tool: Claude runs it, and pi's `pi/extensions/guards.ts` reads the same file. Codex runs the shell-command guards listed in `codex/hooks.json` (trust them once with `/hooks`).

## When to invoke what

Invoke with `/name` in Claude Code, `$name` in Codex, and `/skill:name` in pi.

| Moment                                         | Skill                                                                            |
| ---------------------------------------------- | -------------------------------------------------------------------------------- |
| Small, clear change                            | none                                                                             |
| A question where an edit would be wrong        | `ask`                                                                            |
| Which mechanism should do a job, new or not    | `approach`                                                                       |
| Why I said or did one specific thing           | `why`                                                                            |
| Is this more than the job needs                | `overkill`                                                                       |
| Doubt a claim before acting on it              | `recheck`                                                                        |
| Where things stand, or what this project is    | `overview`                                                                       |
| What is left before ending the session         | `remaining`                                                                      |
| Many files, or code plus docs plus CI          | `writing-plans`, then `executing-plans` (or `executing-plans-agentic` in Claude) |
| Before committing                              | `summarize-changes`                                                              |
| Review                                         | `audit`, or `adversarial-review`                                                 |
| An agent failed and it should not happen again | `fix-yourself`                                                                   |

These load on their own when they apply: `audit` (review), `rewrite` (cutting or restructuring prose), `recall` (past sessions), `tmux` (checking or driving a program in a real terminal), `grilling`, `systematic-debugging`, `test-driven-development`.

## Guards

All of these run in Claude and pi. Codex runs the shell-command guards except `strip-claude-attribution.sh` and `ask-dangerous-git.sh`: Codex has no "ask" decision, so `codex/rules/default.rules` prompts before those git commands instead.

Before a shell command:

- `git-add-before-nix.sh`: no flake evaluation while new files are untracked
- `strip-claude-attribution.sh`: removes Claude attribution from commit messages
- `block-global-search.sh`: no `find`, `fd`, `rg`, or `grep` rooted at `/`, `~`, `/nix`, or another filesystem-wide directory, and no search after a bare `cd` or an unquoted `cd $var` / `cd $(...)` that could land in `$HOME`
- `block-symlink-clobber.sh`: no mv, cp, tee, or redirect over a managed symlink
- `ask-dangerous-git.sh`: asks before rebase, reset, clean, and other history changes
- `block-agent-push.sh`: agent pushes follow `git config eric-agent.push`: unset or `off` (default) denies, `ask` (approve each; Codex treats it as `off`), or `on` (Codex still forbids `git push` in `codex/rules/default.rules`). Agents use `gh` read-only: only `view`, `list`, `status`, `diff`, `checks`, `search`, `repo clone`, `run watch`, `gh status`, and `gh api` without write flags run. In Codex this hook is the allowlist, because a `forbidden` rule for `gh` would also block the reads
- `block-agent-commit.sh`: agent commits follow `git config eric-agent.commit`: `off` (default), `ask` (approve each; Codex treats it as `off`), `branch` (never on `main` or `master`), or `on`. Only the user sets `eric-agent` keys
- `block-git-config-edit.sh`: no redirect, tee, or other write onto a `.git` config file, so `eric-agent` keys change only through `git config`
- `block-shell-edit.sh`: no sed/perl in place, scripts that write, or redirects onto git-tracked files
- `block-sudo-probe.sh`: no `sudo -n` on macOS, where Touch ID approves a plain `sudo`

Before a file read or edit: `deny-symlink-path.sh` (use the real path, not a managed symlink), `block-smart-punct.sh` (no em dashes or curly quotes), `block-write-tracked.sh` (no whole-file Write over a git-tracked file), `block-git-config-edit.sh` (no Write or Edit of a `.git` config file).

After an edit: `treefmt-on-edit.sh` (formats the file), `warn-comment-block.sh` (flags comment blocks of four or more lines).

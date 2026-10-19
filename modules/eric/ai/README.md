# Agent stack

Claude Code, Codex, and pi share one instruction file and one set of skills.

- `AGENTS-global.md` is linked as `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, and `~/.pi/agent/AGENTS.md`. pi-only rules live in `pi/APPEND_SYSTEM.md`.
- `skills/shared/` goes to `~/.claude/skills` and `~/.agents/skills` (Codex and pi). `skills/claude/` is Claude-only. `skills/codex/` also goes to `~/.agents/skills`, so Codex and pi both get it.
- Subagents live in `claude/agents/`, `codex/agents/`, and `pi/agents/`, linked as `~/.claude/agents`, `~/.codex/agents`, and `~/.pi/agent/agents`. Each tool has `auditor` and `recall`. Claude and Codex also have `researcher`, and pi uses its built-in one. Codex agents cannot be made read-only, so read-only is only an instruction there.
- Guard hooks live in `hooks/`, linked as `~/.agents/hooks`. `hooks/guard.sh` execs `agent-guard`, a Go binary built from `guard/` by `modules/overlays/agent-guard.nix`, and exits 2 when it is not on PATH. `guard/checks.go` is the one ordered table of checks and the tools each runs on, with one file per check. It parses a shell command once, following each `cd`, `pushd`, subshell, and literal variable so every call knows its directory, then runs each check and prints one decision. A change under `guard/` goes live with `just switch`. Claude (`claude/settings.json`), Codex (`codex/hooks.json`), and pi (`pi/extensions/guards.ts`) each call it once per event, naming the harness. Codex also runs `tmux-bell.sh` and `tmux-agent-resume.sh` from `codex/hooks.json` (trust them once with `/hooks`, and again after an entry there changes).

## When to invoke what

Invoke with `/name` in Claude Code, `$name` in Codex, and `/skill:name` in pi.

| Moment                                            | Skill                                                                                             |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| Small, clear change                               | none                                                                                              |
| A question where an edit would be wrong           | `ask`                                                                                             |
| Which mechanism should do a job, new or not       | `approach`                                                                                        |
| Why I said or did something, or what a line means | `why`                                                                                             |
| Is this more than the job needs                   | `overkill`                                                                                        |
| Doubt a claim before acting on it                 | `recheck`                                                                                         |
| What is left before ending the session            | `remaining`                                                                                       |
| Many files, or code plus docs plus CI             | `writing-plans`, then `executing-plans` (or `executing-plans-agentic` in Claude)                  |
| Before committing                                 | `summarize-changes`                                                                               |
| Review                                            | `audit` (repo, area, or diff), or `review` (two-model red-team of a diff, file, or plan, by hand) |
| Is the code split the right way into parts        | `architecture-review` (a full `audit` runs it too)                                                |
| An agent failed and it should not happen again    | `fix-yourself`                                                                                    |
| Hand the session, or one thread, to an agent      | `handoff`                                                                                         |
| Start a new dev project                           | `new-project`                                                                                     |

## Guards

All of these run in Claude and pi. Codex runs the shell-command checks, but it has no "ask" decision and applies a rewrite only with an allow, so under Codex `agent-guard` turns every ask into a deny and drops the attribution rewrite. `codex/rules/default.rules` still forbids `git push` and `gh pr` writes, which holds even while the hook is untrusted.

Before a shell command:

- `git-add-before-nix`: no flake evaluation while new files are untracked
- `strip-claude-attribution`: removes Claude attribution from commit messages
- `block-global-search`: no `find`, `fd`, `rg`, or `grep` rooted at `/`, `~`, `/nix`, or another filesystem-wide directory, including a relative search after a `cd` there, and no relative search after an unquoted `cd $var` / `cd $(...)` that could land in `$HOME`
- `block-symlink-clobber`: no mv, cp, tee, redirect, in-place sed/perl, or truncate onto any symlink
- `ask-dangerous-git`: asks before rebase, reset, clean, and other history changes
- `block-agent-push`: agent pushes (`git push`, `send-pack`, `subtree push`, `lfs push`) follow `git config eric-agent.push` in every repo the command pushes from: unset or `off` (default) denies, `ask` (approve each; Codex denies it), or `on` (Codex still forbids `git push` in `codex/rules/default.rules`). Agents use `gh` read-only: only `view`, `list`, `status`, `diff`, `checks`, `search`, `repo clone`, `run watch`, `gh status`, and `gh api` GETs run (fields need an explicit `-X GET`, since gh otherwise sends them as a POST). In Codex this hook is the allowlist, because a `forbidden` rule for `gh` would also block the reads
- `block-agent-commit`: agent commits, merges, reverts, cherry-picks, `git am`, `commit-tree`, `update-ref`, `subtree`, and any `pull` without `--ff-only` follow `git config eric-agent.commit` in every repo the command commits in: `off` (default), `ask` (approve each; Codex denies it), `branch` (never on `main` or `master`), or `on`. `--abort`, `--quit`, and `commit --dry-run` always run, as does `push --dry-run` or `-n` in `block-agent-push`. Only the user sets `eric-agent`, `alias`, and `include` keys. Both gates deny `-c` or `--config-env` aliases and includes, `GIT_DIR`, `GIT_WORK_TREE`, and `GIT_CONFIG*` assignments, and a gated command with `--git-dir`, `--work-tree`, `core.worktree`, `find -execdir`, or a repo the guard cannot resolve (a `cd` or `-C` through an unknown variable), since each can move git past the repo or config the gate reads. Each `cd`, `pushd`, `-C`, `env -C`, and `sudo -D` before the command is followed. Rebase stays with `ask-dangerous-git`
- `block-git-config-edit`: no redirect, tee, or other write onto a `.git` config file, `~/.gitconfig`, or `~/.config/git/config`, so `eric-agent` keys change only through `git config`
- `block-shell-edit`: no sed/perl in place, scripts that write, or redirects, cp, or mv onto git-tracked text files. Binary files, which the edit tool cannot change, are exempt
- `block-sudo-probe`: no `sudo -n` on macOS, where Touch ID approves a plain `sudo`
- `block-exec-flags`: no `fd -x`, `rg --pre`, `sort -o`, `tree -o`, or `git diff`/`log`/`show --output`, which would run or write through tools the agents approve as read-only
- `block-rm`: no `rm`, since `trash` keeps a way back
- `block-tmux-kill`: no kill of a session, window, pane, or server on the user's tmux. A private `-L` or `-S` server stays the agent's to kill

`agent-guard` denies a command its zsh parser (`mvdan.cc/sh`, the library behind shfmt) cannot parse, and a shell that reads its script from a pipe, since no check can see either. A here-string, heredoc, `eval`, `watch`, or `script -c` is checked like a `bash -c` script, at any depth.

Before a file read or edit: `deny-symlink-path` (use the real path, not a managed symlink), `block-smart-punct` (no em dashes or curly quotes), `block-write-tracked` (no whole-file Write over a git-tracked file), `block-git-config-edit` (no Write or Edit of a `.git` config file).

After an edit: `treefmt-on-edit` (formats the file), `warn-comment-block` (flags comment blocks of four or more lines).

## pi

Extensions in `pi/extensions/`, linked per file into `~/.pi/agent/extensions` by `ai.nix`, so a new extension needs `just switch`:

- `guards.ts`: runs `hooks/guard.sh` before and after each tool call, and `hooks/tmux-bell.sh` on `agent_settled`. It does not run `Notification` hooks
- `managed-paths.ts`: a path that is itself a symlink is already denied by `deny-symlink-path`, since `guards.ts` loads first. This blocks writes through a symlink that resolves outside `~/nixos-config`, `~/.flake`, or `~/.config`
- `side-conversations.ts`: `/side` opens a side session, `/btw` a tool-free parallel conversation
- `reflect.ts`: `/reflect` reviews the session for durable learning
- `time.ts`: a `time` tool
- `git-signing.ts`: signs agent commits with `ssh-keygen` instead of 1Password, like the `GIT_CONFIG_*` env in `claude/settings.json`
- `image-attachments.ts`: attaches image files whose paths appear in a prompt
- `tmux-agent-resume.ts`: runs `hooks/tmux-agent-resume.sh pi` at session start, since `guards.ts` does not run `SessionStart` hooks
- `statusline.ts`, `minimal-startup.ts`, `fullscreen-tweaks.ts`: UI

`pi/lib/` holds helpers for extensions, since pi loads every `.ts` in `extensions/` as an extension. `mcp.json` starts the `context7-mcp` and `cornell-confluence-mcp` wrappers from `ai.nix`, plus `railway mcp`.

## Tests

CI's `ai-agent-tests` job in `.github/workflows/check.yml` runs `hooks/test.sh` and the `pi/tests` suite. To run them locally, run that job's steps from the repo root, with `go` from the devShell. `test.sh` builds `agent-guard` from `guard/` and fails if a check in `guard/checks.go` or a script in `claude/settings.json` has no test. `go test` in `guard/`, which the package build also runs, checks the table and that the walk reaches a call inside every shell construct. So a new check is one function, one row in `checks.go`, and a `test.sh` case. The `pi/tests` suite runs the `agent-guard` on PATH, so locally it tests the installed binary until the next switch.

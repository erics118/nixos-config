---
name: tmux
description: Use before starting any tmux session or server, or when a terminal program must run in a real terminal, either to verify what it draws (nvim rendering, a statusline, a dialog, colors, cursor position, a TUI like codex or claude) or to drive it step by step (a REPL, a debugger like lldb, a menu or picker). Runs it in a private tmux server
---

tmux gives the program a real terminal you read with `capture-pane` and type into with `send-keys`. Two uses:

1. **Check the screen:** the result is something drawn (rendering, layout, colors, highlight groups, prompts, dialogs, key handling). First check whether a headless route settles it (`nvim --headless -c '...' +q`, a config dump, a test).
2. **Drive an interactive program:** each step depends on the last output (`lldb`, `gdb`, `python -i`, `nix repl`), or the program wants arrow keys or a menu choice. Send one step, wait for its output, read it, then decide the next step.

Use something else for:

- A long-running server or log: run it in the background and watch it with your agent's background-command or monitor tool.
- A password, passphrase, login, or ssh host-key prompt: stop and ask the user, since that decision is theirs.
- Git: never run git inside tmux.

## Recipe

```sh
S=agent-$$-$RANDOM
tmx() { tmux -L "$S" -f /dev/null "$@"; }
tmx new-session -d -s main -x 120 -y 40 -c "$PWD" 'nvim -n file.lua'
tmx set -t main remain-on-exit on

# ready: poll for a marker the real program draws, with a bound
ready=0
for i in $(seq 100); do
  [ "$(tmx display -p -t main '#{C/r:NORMAL}')" != 0 ] && { ready=1; break; }
  sleep 0.1
done
[ "$ready" = 1 ] || { tmx capture-pane -p -t main; echo NOT READY; }

# input: flags before keys, free text with -l, Enter in its own call
tmx send-keys -t main -l ':echo "hello world"'
tmx send-keys -t main Enter

# output
tmx capture-pane -p -t main
tmx capture-pane -p -e -t main
tmx display -p -t main '#{cursor_x},#{cursor_y} #{pane_dead} #{pane_dead_status}'

# cleanup, on failure paths too
tmx kill-server
rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$S"
```

A screen check is done when a capture shows the expected text, colors, or cursor cell. A driven session is done when the capture shows the final step's output. Either way, finish with `tmux -L "$S" ls` reporting no server.

## Isolation

- Every call goes through the `tmx` function with a fresh `-L` name per run. The agent often runs inside the user's own tmux (`$TMUX` is set), and a bare `tmux` command reaches the user's sessions.
- Use `-L`, not `-S <path>`: socket paths have an OS length limit (about 104 bytes on macOS), and scratch paths are often longer.
- `-f /dev/null` skips the user's tmux.conf. It takes effect on the call that starts the server.
- To test the user's tmux config, `source-file` only the files under test into the `-f /dev/null` server. The full config restores the user's saved sessions and relaunches the agents in them.
- Always pass `-x` and `-y`. Layout depends on size, and the default is 80x24.
- Keep tmux in a function. `T="tmux -L $S"; $T ...` fails in zsh, which does not word-split.
- Guard any `cd` or search root: `cd -- "${dir:?}"`.

## Waiting

Wait by polling a condition with a bound, and print the screen when the bound runs out.

- Text on screen: `tmx display -p -t main '#{C/r:REGEX}'` prints the matching line number, or 0. Or `tmx capture-pane -p -t main | grep -q REGEX`.
- Pick the marker from a first capture of the real program. Stock markers fail under a user config: `^~` never matches when the config hides end-of-buffer `~`, while the statusline mode text does.
- Anchor the pattern. The typed command line contains the marker too: `#{C:READY}` matched the echoed `echo READY` line before the output.
- Shell command done: append `; tmux wait-for -S done` to the pane command, then `timeout 30 tmux -L "$S" wait-for done`. A signal sent before the wait starts is kept once. Wrap every `wait-for` in `timeout`.
- Program exit: with `remain-on-exit on`, read `#{pane_dead}` and `#{pane_dead_status}`.
- `new-session` returns 0 even when the command exits at once or does not exist, and `#{pane_current_command}` shows the shell right after start. Judge readiness from the screen.

## Input

- Each `send-keys` argument is a key name (`Enter`, `Escape`, `C-c`, `BSpace`, `Up`, `F5`) or literal text. `-l` sends the whole argument as literal text.
- Flags come before the keys: `send-keys -t main i -l SEP` types `-lSEP`.
- `Escape x` in one call reaches nvim as `<M-x>`. Send `Escape` alone, pause about 0.2 s, then the next key.
- Multi-line text: `printf '%s' "$text" | tmx load-buffer -` then `tmx paste-buffer -p -d -t main`.
- After input, poll for the screen to change before capturing.

## Output

- `capture-pane -p` prints the visible screen. `-S -200` adds history, `-J` joins wrapped lines.
- `-e` keeps color escapes. Truecolor shows as `38;2;R;G;B`. Pipe through `cat -v` to read it.
- Full-screen apps use the alternate screen, which has no history.
- `#{cursor_x},#{cursor_y}` gives the cursor cell, `#{pane_width}x#{pane_height}` the size.
- `pipe-pane -O -t main 'cat >> log'` records the raw stream, for transient output a capture can miss.
- Messages can land in a float or notification instead of the bottom line. Search the whole capture.

## Cleanup

- A fresh socket name per run. A `new-session` that reaches an old server still shutting down fails with `server exited unexpectedly` or `duplicate session`.
- `kill-server` leaves the socket file. The `rm -f` in the recipe removes it.

## Program-specific

- nvim: `nvim -n` skips swap files and the "swap file exists" prompt. `-i NONE` leaves shada alone. `--clean` skips the user config, so use it only for a baseline.
- codex: start it with `-c check_for_update_on_startup=false` to skip the update prompt, in a folder that is already trusted. Trusting a new folder writes to `~/.codex/config.toml`, which is repo-managed.
- Any TUI can open a first-run dialog (login, trust, changelog). Capture the first screen and handle the dialog before asserting anything.
- tmux 3.5+ sets `COLORTERM=truecolor` in the pane, so nvim enables `termguicolors`. To test the fallback, run `env -u COLORTERM nvim -n` as the pane command.
- When a test pane runs an agent, unset the outer agent's variables (`CLAUDECODE`, `CLAUDE_CODE_*`, `HERDR_*`), never `TMUX` or `TMUX_PANE`. The test server sets those for the pane, and tmux-aware tools refuse without them.
- The pane's TERM is `tmux-256color`. Behavior that depends on the user's real terminal (wezterm or kitty key protocols, graphics) does not reproduce here.

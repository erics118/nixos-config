---
name: verify
description: Use before reporting a change as done, fixed, or working, and when the user asks to test, check, or verify it.
---

A check counts only when it exercises the behavior the user will use, on the real path, after the change is live. A stand-in check (another entry point, synthetic events, generated output) counts only after you confirm, from the program's source, that it runs the same path as the real behavior. Before writing any unverified, not-checked, or "I'll verify later" claim, or handing the user a check to run, settle it yourself with the steps below.

1. Name the behavior. One line: what the user does and what they should see. Name the output that would prove it and the output that would disprove it.
2. Make it live. Per the Environment rules: switch only when they allow it, then restart or reload whatever loaded the old version (see the recipes). If the change waits on a pending switch, report it as `Not checked: <behavior> (switch pending)` and stop here.
3. Exercise it with the recipe below that matches. Read the real output, a capture, or a screenshot.
4. Judge. A match proves it. A mismatch, an error, a blocked attempt, or an inconclusive run settles nothing: fix it or try the next recipe.

Done when: the report carries a `Checked: <command> -> <result>` line from step 3 for every behavior the request named.

## Recipes

The user works at the screen while you do. Before a recipe that opens a window, takes a screen capture, moves focus, or sends key events, say what will appear, for how long, and what gets captured, then wait for a yes. Then turn on the red apple warning from the Execution policy rules before the first action.

Prefer a headless recipe when one reaches the behavior.

- Terminal output (nvim, tmux, a shell prompt, a statusline, a TUI, colors) counts as exercisable: the tmux skill. Start a fresh instance, since a running one keeps the old config. Capture the pane.
- Code with tests: run the tests that cover the change, then one real run of the entry point the user uses.
- A daemon or service: restart it, then read its status and its log since the restart (`launchctl print gui/$UID/<label>`, `systemctl status`, `journalctl -u <unit> --since`). On another host, use `tailscale ssh`.
- A GUI on macOS (sketchybar, a window manager, an app): reload it (`sketchybar --reload`), then `screencapture -x <scratch>/shot.png` into the task's scratch directory and read the image. Compare against a screenshot from before the change when the change is visual.
- Firefox chrome: the firefox-ui skill in `~/nixos-config`.
- A keyboard shortcut or a clipboard action: make the expected value unique (a URL or text that can't already be there), seed the clipboard with a different sentinel, send only the action under test (`cliclick kd:cmd,shift t:c ku:cmd,shift` for real key events), then read the clipboard. Inconsistent runs mean it does not work.
- A remote host or root context: run it the way the real caller does. Use `sudo env -i <cmd>` for a systemd unit, since plain `sudo` leaks `SUDO_UID`.

When no recipe reaches the behavior, write `Not checked: <what> (needs your eyes: <how>)`, listing every recipe you tried and why it fell short.

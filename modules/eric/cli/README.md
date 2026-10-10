# CLI

## Commands

| Command         | What it does                                                          | Source                              |
| --------------- | --------------------------------------------------------------------- | ----------------------------------- |
| `agent-side`    | open another claude or pi in a tmux split, for their /side commands   | `scripts/agent-side.sh`             |
| `ask`, `?`      | one-shot LLM query through OpenRouter                                 | `scripts/ask.sh`                    |
| `cuvpn`         | connect to the Cornell VPN with credentials from 1Password            | `scripts/cuvpn.sh`                  |
| `mvproj`        | move a project folder with its claude and pi history and tmux session | `scripts/mvproj.sh`, `zsh/init.zsh` |
| `rv`            | run a command in the CS 3410 RISC-V container                         | `scripts/rv.sh`                     |
| `rv-debug`      | debug in the same container, with core dumps on                       | `scripts/rv-debug.sh`               |
| `scratch`       | cd into a fresh `~/dev/scratch/<date-time>` folder                    | `zsh/init.zsh`                      |
| `t`             | open or pick a local tmux session through sesh                        | `scripts/t.sh`                      |
| `sesh-pick`     | the fzf picker behind `t`, creating `~/dev/<name>` on no match        | `sesh/sesh-pick.sh`                 |
| `tmux-popup`    | open, switch, or close the tmux popups: picker, scratch shell, yazi   | `scripts/tmux-popup.sh`             |
| `rtmux`, `r`    | attach to a persistent session on a remote host over mosh or autossh  | `rtmux/rtmux.sh`                    |
| `ns`            | fuzzy search nixpkgs packages and home-manager and nix-darwin options | `ns/ns.sh`                          |
| `eriz`          | client for the eriz.cc API                                            | `eriz/eriz.sh`                      |
| `keepawake`     | keep the Mac awake, lid closed included, until it exits (macOS)       | `scripts/darwin/keepawake.sh`       |
| `lctl`          | start/stop/restart/status a launchd user agent by short name (macOS)  | `scripts/darwin/lctl.sh`            |
| `o`             | `open`, defaulting to the current directory (macOS)                   | `scripts/darwin/o.sh`               |
| `pbcopy-secret` | `pbcopy`, marked concealed so clipboard managers skip it (macOS)      | `scripts/darwin/pbcopy-secret.sh`   |

`scripts.nix` turns each `.sh` file in `scripts/` into a command for every host, and each one in `scripts/darwin/` into a command for macOS only.

## Applying edits

- Live: files linked with `repoFile` or `repoFileAll` (`tmux/`, `yazi/`, and the files `herdr.nix` links). Edits apply without a rebuild.
- A new file in a `repoFileAll` directory, or a new `repoFile` link, needs `just switch`, since links are made at eval time.
- Needs `just switch`: every other file here. `readFile`, `source = ./...`, and `${./...}` copy it into the store.

# Desktop

## Applying edits

| Config                               | Linked                                     | After an edit                                                                                |
| ------------------------------------ | ------------------------------------------ | -------------------------------------------------------------------------------------------- |
| `sketchybar/`                        | live (`repoFile`)                          | `sketchybar --reload`                                                                        |
| `wezterm/`                           | live                                       | reloads on save                                                                              |
| `hyprland/`                          | live, from `features/desktop/hyprland.nix` | `hyprctl reload`. hypridle and hyprpaper read their `.conf` once at start, so restart them   |
| `karabiner/karabiner.edn`            | live                                       | the `goku-watch` agent reruns goku, log in `~/.local/state/goku.log`                         |
| `raycast/scripts/`                   | live                                       | add `~/.config/raycast/script-commands` once with "Add Script Directory" in Raycast settings |
| `firefox/chrome/`, `firefox/user.js` | live, per entry in `firefox.nix`           | see `firefox/README.md`                                                                      |
| `smhkd/smhkdrc`                      | store copy                                 | `just switch`, then `smhkd -r`                                                               |
| `yabai/`                             | store copy                                 | `just switch`, then `yabai --restart-service`                                                |
| `espanso/`                           | store copy                                 | `just switch`                                                                                |

## Forks

- sketchybar, yabai, smhkd, goku, front, mosh, and wezterm come from personal forks or source pins. See `modules/overlays/`.

## Manual tools

- `capsled` (`capsled.nix`): drives the caps lock LED by hand, `capsled on [--until-input] | off | auto | wait <command> [args...]`.

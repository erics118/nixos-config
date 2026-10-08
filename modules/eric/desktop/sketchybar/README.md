# Sketchybar

`sketchybarrc` loads `helpers/` and then `init.lua`, which sets up the bar and the items in `items/init.lua`:

- left: apple, smhkd, menus, spaces, yabai, front_app
- right: calendar, battery, wifi, weather, sleep, cpu

## Dependencies

- The Lua module `~/.local/share/sketchybar_lua/sketchybar.so` comes from nixpkgs `sbarlua`, linked by `sketchybar.nix`. Without it the bar does not start.
- sketchybar is built from the fork in `modules/overlays/sketchybar.nix`. `typographical_width` in `default.lua` is merged upstream (FelixKratz/SketchyBar#826) but not yet in a release, so the stock nixpkgs build lacks it.

## Helpers

- `helpers/init.lua` runs `make` in `helpers/` on every start. It builds `event_providers`, `menus`, and `symbol_image` into ignored `bin/` directories, and compile errors go to `/tmp/sketchybar_eric.err.log`.
- `helpers/symbols.lua` caches each rendered PNG in `helpers/symbol_image/bin/` and renders only when the file is missing. After changing `symbol_image.m`, delete the cached PNGs there.
- `battery.lua` and `sleep.lua` run `sudo pmset`. That works only for the exact commands allowed NOPASSWD in `modules/features/base/darwin.nix`.
- `wifi/` holds the JXA scripts behind the wifi item. See `wifi/README.md`.
- `app_icons.lua` loads the icon map from the `sketchybar-app-font` package, linked by `sketchybar.nix`, so names match the installed font.

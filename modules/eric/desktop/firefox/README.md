# Firefox

Chrome customization for Firefox Developer Edition on macOS, installed from `/Applications` and not from nix, tested on 158. On Linux it is the nixpkgs Firefox Developer Edition from `programs.firefox`, tested on 158.

## How it loads

- `firefox.nix` links `chrome/` and `user.js` into the profile `gcl3mics.dev-edition-default` on macOS and `~/.config/mozilla/firefox/ob0g1466.dev-edition-default` on Linux, so edits are live. It links each top-level entry under `chrome/` by name, so a new one needs its own line there.
- `.uc.js` scripts in `chrome/JS/` run through [fx-autoconfig](https://github.com/MrOtherGuy/fx-autoconfig), from the `fx-autoconfig-src` flake input. On macOS its two program files go into the app bundle on every home-manager activation, so a Firefox update that wipes them is fixed by the next switch. On Linux the nix wrapper builds them in through `programs.firefox.autoConfigFiles`.
- A shadow-DOM part that `userChrome.css` can't select is styled through a custom property the part reads, since custom properties inherit through the shadow boundary.
- `chrome/resources/` is linked but empty. fx-autoconfig serves it as `chrome://userChrome/content/`, for an author sheet and the `.uc.js` that loads it when a variable can't reach a part.

## After an edit

- `.uc.js` scripts: restart with the startup cache cleared, using the button in `about:support` or Tools > userScripts > Clear startup cache & Restart Firefox Developer Edition
- `userChrome.css`, `userContent.css`: restart Firefox

## Extension dependencies

- `sidebar-launcher-footer.uc.js` targets the Sidebery fork (add-on id `sidebery-fork@erics118`) by its sidebar view id. With another Sidebery build the footer still lays out, but the toolbar sidebar button toggles a view that does not exist and the Sidebery launcher button loses its first place.
- `userChrome.css` reads colors set by Adaptive Tab Bar Colour (ATBC).
- `userContent.css` themes about: pages with Catppuccin Mocha in dark mode. ATBC can't read about: pages and paints their toolbar with built-in colors, so an ATBC rule `about:*` set to `#1e1e2e` makes the toolbar match.

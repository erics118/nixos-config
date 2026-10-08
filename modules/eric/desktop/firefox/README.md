# Firefox

Chrome customization for Firefox Developer Edition, installed from `/Applications` and not from nix. Tested on 158.

## How it loads

- `firefox.nix` links `chrome/` and `user.js` into the profile `gcl3mics.dev-edition-default`, so edits are live. It links each top-level entry under `chrome/` by name, so a new one needs its own line there.
- `.uc.js` scripts in `chrome/JS/` run through [fx-autoconfig](https://github.com/MrOtherGuy/fx-autoconfig), from the `fx-autoconfig-src` flake input. Its two program files go into the app bundle on every home-manager activation, so a Firefox update that wipes them is fixed by the next switch.
- `resources/userChrome.au.css` is an author sheet, loaded by `userChrome_au_css.uc.js`, for `::part` selectors that `userChrome.css` can't reach.

## After an edit

- `.uc.js` scripts: restart with the startup cache cleared, using the button in `about:support` or Tools > userScripts > Clear startup cache & Restart Firefox Developer Edition
- `userChrome.css`: restart Firefox

## Extension dependencies

- `sidebar-launcher-footer.uc.js` targets the Sidebery fork (add-on id `sidebery-fork@erics118`) by its sidebar view id. With another Sidebery build the footer still lays out, but the toolbar sidebar button toggles a view that does not exist and the Sidebery launcher button loses its first place.
- `userChrome.css` reads colors set by Adaptive Tab Bar Colour (ATBC).

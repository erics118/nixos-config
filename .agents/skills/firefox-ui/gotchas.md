# Firefox chrome gotchas

Paths are relative to `modules/eric/desktop/firefox/` unless they name a file inside `omni.ja`.

## Urlbar popover

Proton branch (`browser.nova.enabled` off). Read the installed `urlbar.css`, `urlbar/*.css`, and `chrome/browser/content/browser/urlbar/UrlbarInputBase.mjs` first. `UrlbarInput.mjs` is only a subclass of it.

- While results show, `updatePopover()` in `UrlbarInputBase.mjs` sets `[popover-open]` on `#urlbar`. Older builds used `[breakout]` and `[breakout-extend]`, which no longer exist.
- Under `[popover-open]`, `urlbar.css` grows `.urlbar-input-container` with negative margins and matching padding (`--urlbar-input-growth-open-*`), so the toolbar layout does not move.
- `chrome/userChrome.css` overrides the container's `padding-inline`, so its `#urlbar[popover-open]` rule adds the growth back. Without it the contents slide when results open.

## Transparent browser

`browser.tabs.allow_transparent_browser` is pinned `false` in `user.js` to keep tab and sidebar canvases opaque. Keep it explicit so transparency stays off even if the default changes.

Firefox puts `transparent="true"` on every content browser, tab content included, not just the sidebar. That strips the opaque canvas the content process would paint. Pages with no background of their own render on the window vibrancy, and nothing covers the content area until first paint: a white flash on every new tab.

Do not reclaim it from the chrome side. A canvas on `.browserStack` or `.browserContainer` only moves the problem, because its color fills the same pre-paint window. The chrome cannot tell when content has painted. These look like paint signals but are not:

- `browser[remoteType]` records the process a browser started in. A tab opened on about:newtab reads `privilegedabout` forever, because Fission switches processes in the parent via DocumentChannel and skips the JS `updateBrowserRemoteness` that rewrites the attribute.
- `browser[blank]` and `[pendingpaint]` cover only the AsyncTabSwitcher window. A second unpainted gap follows once `[blank]` clears.
- The tab's `busy` attribute clears at load-stop, long after first paint.

A uc.js that strips the attribute on the `tabbrowser-browser-element-will-be-inserted` notification works, but was rejected as fragile: if it breaks, every no-background page regresses. Pref off keeps both tabs and Sidebery opaque. Do not add exceptions for sidebar transparency.

The toolbar and window vibrancy is unrelated, and this profile has none. Firefox draws it from `body::after` in `browser-shared.css`, gated on `-moz-native-theme` and `:not([lwtheme])`. `user.js` turns native theme off, and ATBC sets `lwtheme`. The override that once restored it in `chrome/resources/userChrome.au.css` was removed in 4b99031.

## Content-area rounding

The sidebar revamp rounds the web content's chrome-facing corners and draws a separator whenever a sidebar panel shows. Sidebery lives in the native `#sidebar-box`, so it sets `#tabbrowser-tabbox[sidebar-shown]` and triggers this. Sidebery cannot style web content, so a rounded or bordered corner on the page is always Firefox.

The source is `chrome/browser/skin/classic/browser/tabbrowser/content-area.css` in the browser jar. The rounding rules belong to separate branches:

- Under `@media -moz-pref("browser.nova.enabled")`, `#tabbrowser-tabpanels > :not(.split-view-panel) .browserContainer` sets `border-start-start-radius: var(--content-area-start-radius)` plus a `--chrome-content-separator-color` border on the chrome-facing edges. This branch is inactive in this profile.
- Under `@media -moz-pref("sidebar.revamp")` with Nova off, the plain `.browserContainer` rule sets `border-start-start-radius: var(--border-radius-medium)` under `[sidebar-shown]` when `sidebar.position_start` is on, or `border-start-end-radius` when it is off. The sidebar revamp also sets `overflow: clip` and an `outline` using `--chrome-content-separator-color`.

Overriding `--content-area-start-radius` alone does not reach the active literal radius or remove the clip. The working override is the `.browserContainer` rule in `chrome/userChrome.css` that sets the variable and the radii flat outright.

The active separator is an `outline`. The Nova branch uses a `border`; `outline: none` does not remove that border.

## ⇧⌘C copy URL

`chrome/JS/copy-url.uc.js` binds ⇧⌘C to copy the tab URL. It is not a macOS App Shortcut. App Shortcuts on items inside the system Share submenu show the key but never fire on a real press, and a dead key-equivalent can swallow the key before Firefox sees it. So the App Shortcut was removed with `defaults delete org.mozilla.firefoxdeveloperedition NSUserKeyEquivalents`.

`kill-inspector-shortcuts.uc.js` strips the devtools ⇧⌘C (`key_inspectorMac`) and ⌘⌥C (`key_inspector`) so the combo is free. `focus-mode.uc.js` binds ⇧⌘F.

---
name: firefox-ui
description: Use when changing or debugging Firefox chrome (userChrome.css, userChrome.au.css, .uc.js scripts, user.js prefs) or the look and keys of the browser window.
---

The config lives in `~/nixos-config/modules/eric/desktop/firefox/`. Read its `README.md` first for how it loads, how to reload, and which extensions it depends on.

1. Read the installed source. The answer to "which rule does this" is in the installed build, not in memory or searchfox. Extract the files you need from the browser jar into the scratchpad (a nonzero exit with "extra bytes" warnings is normal):
   ```bash
   unzip -o -d <scratchpad>/omni "/Applications/Firefox Developer Edition.app/Contents/Resources/browser/omni.ja" '<path>'
   ```
   List paths with `unzip -l`. The browser jar holds the chrome (`chrome/browser/skin/classic/browser/` for CSS, `chrome/browser/content/browser/` for JS and `browser.xhtml`). `Contents/Resources/omni.ja` holds only toolkit.
   Done when: you have read every installed rule that touches the target element and property.
2. Override the winner. List every rule on the target, and whether each sets the property through a variable or a literal (plus any `overflow: clip`). Override the property itself with the value form that wins. A variable override only reaches rules that read the variable.
3. Reload per the README. Restarting asks "Close N tabs?". Session restore is on, so closing is safe.
4. Verify on the live window with the verify skill: a `screencapture` for looks, the clipboard recipe for keys. Get the discriminating detail from the user first for a visual bug: where on screen, what color, what sequence.

Known mechanics, read before touching these areas: [gotchas.md](gotchas.md) (urlbar popover, transparent browser, content-area rounding, the ⇧⌘C copy-URL key). To restore the removed Arc-like page frame: [page-frame.md](page-frame.md).

# Restoring the page frame

The 8px Arc-like page frame (a rounded border around the rendered content) was removed from `modules/eric/desktop/firefox/chrome/userChrome.css` in bf4a185 (2026-09-21). To restore it, re-add the pieces below and revert the `#navigator-toolbox` comment.

Tokens in `:root`:

```css
/* Arc-like page frame around the rendered content */
--page-frame-width: 8px;
--page-frame-radius: 16px;
```

Frame block and sidebar-hidden restore, inside `#main-window`, after the `#sidebar-container[data-sidebery-bottom-launcher] ~ #sidebar-box` rule:

```css
/* --- Page frame (Arc-like rounded border around the rendered page) ---
     Sidebery owns the top-left join, so leave that corner and the left edge
     open. */
#tabbrowser-tabbox {
  border-style: solid;
  border-color: var(--atbc-raised-surface);
  /* don't add border to left side b/c sidebery/sidebar is already there */
  border-width: var(--page-frame-width) var(--page-frame-width)
    var(--page-frame-width) 0px;
  border-left-color: transparent !important;
  border-radius: var(--page-frame-radius) !important;
  /* with no left border to subtract, the left corners' visible (padding-box)
       curve runs the full radius horizontally but radius - frame vertically,
       reading as a stretched ellipse. Pre-shrink the horizontal radius by the
       frame width so both axes land on radius - frame, matching the right. */
  border-top-left-radius: calc(
      var(--page-frame-radius) - var(--page-frame-width)
    )
    var(--page-frame-radius) !important;
  border-bottom-left-radius: calc(
      var(--page-frame-radius) - var(--page-frame-width)
    )
    var(--page-frame-radius) !important;
  background-clip: padding-box !important;
  overflow: hidden !important;
}

/* When the sidebar is closed, #sidebar-box gets a native `hidden` attribute
     (Firefox's own, not Sidebery). Nothing occupies the left edge then, so
     restore the frame + top-left rounding to keep the page inset even. */
#browser:has(#sidebar-box[hidden]) #tabbrowser-tabbox {
  border-left-width: var(--page-frame-width) !important;
  border-left-color: var(--atbc-raised-surface) !important;
  /* left border is back, so both left corners are symmetric again: undo the
       horizontal compensation above or they stretch the other way */
  border-top-left-radius: var(--page-frame-radius) !important;
  border-bottom-left-radius: var(--page-frame-radius) !important;
}
```

Focus-mode restore, inside `#main-window[focus-mode]`, after the `display: none` block:

```css
/* Sidebery is gone, so close the page frame on the left like the
     sidebar-hidden case above. */
#tabbrowser-tabbox {
  border-left-width: var(--page-frame-width) !important;
  border-left-color: var(--atbc-raised-surface) !important;
  border-top-left-radius: var(--page-frame-radius) !important;
  border-bottom-left-radius: var(--page-frame-radius) !important;
}
```

Revert the `#navigator-toolbox` comment so it credits the frame:

```css
/* #navigator-toolbox is a .chrome-block whose 1px bottom border sits right
     under the bookmarks bar. The 8px page frame already supplies that
     separation, so drop the extra line. */
```

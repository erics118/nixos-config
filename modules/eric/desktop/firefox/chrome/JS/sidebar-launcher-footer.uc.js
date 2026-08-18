// sidebar-launcher-footer.uc.js
// Move Firefox's native sidebar launcher (including Synced Tabs) to a
// horizontal footer across the Sidebery pane. The launcher lives inside the
// sidebar-main shadow DOM, so we inject an adopted stylesheet. adoptedStyleSheets survives the lit
// re-renders that would clobber a plain injected <style>.
(function () {
  const VIEW = "sidebery-fork_erics118-sidebar-action";

  // Firefox's revamped toolbar button toggles the whole sidebar launcher and
  // runs its slide animation. Sidebery's _execute_sidebar_action shortcut
  // instead toggles only the Sidebery panel. Intercept the toolbar command in
  // the capture phase so the button behaves exactly like that shortcut.
  if (!window._sideberyToolbarToggleInstalled) {
    window._sideberyToolbarToggleInstalled = true;
    window.addEventListener(
      "command",
      (event) => {
        if (event.target?.id !== "sidebar-button") return;
        event.preventDefault();
        event.stopImmediatePropagation();
        SidebarController.toggle(VIEW);
      },
      true,
    );
  }

  const CSS = `
    .wrapper,
    .buttons-wrapper {
      height: var(--sidebery-launcher-height) !important;
    }
    .wrapper {
      display: block !important;
    }
    slot[name="tabstrip"] {
      display: none !important;
    }
    .buttons-wrapper,
    button-group.tools-and-extensions.actions-list,
    .bottom-actions {
      flex-direction: row !important;
      align-items: center !important;
    }
    .buttons-wrapper {
      width: 100% !important;
      justify-content: center !important;
    }
    button-group.tools-and-extensions.actions-list {
      /* Keep the pill's side gutters fixed; only its middle grows or shrinks
         with the Sidebery pane. */
      flex: 1 !important;
      width: auto !important;
      margin-inline: var(--sidebery-launcher-pill-margin) !important;
      /* Stretch only the gaps between buttons. The 3px pill padding remains
         the fixed space before the first and after the last button. */
      justify-content: space-between !important;
      gap: var(--sidebery-launcher-pill-gap) !important;
      padding: var(--sidebery-launcher-pill-padding) !important;
      border: 1px solid color-mix(in srgb, currentColor 20%, transparent) !important;
      border-radius: var(--chrome-pill-radius) !important;
      background-color: color-mix(in srgb, currentColor 10%, transparent) !important;
    }
    button-group.tools-and-extensions.actions-list > moz-button:not(.tools-overflow) {
      --button-size-icon: var(--sidebery-launcher-button-size) !important;
      --icon-size: var(--sidebery-launcher-icon-size) !important;
      --button-padding-icon: 0 !important;
      --button-border-radius: var(--chrome-pill-radius) !important;
      --button-outer-padding: 0 !important;
      --button-outer-padding-block-start: 0 !important;
      --button-outer-padding-block-end: 0 !important;
      --button-outer-padding-inline: 0 !important;
    }
    button-group.tools-and-extensions.actions-list > moz-button::part(button) {
      width: var(--sidebery-launcher-button-size) !important;
      height: var(--sidebery-launcher-button-size) !important;
      min-height: var(--sidebery-launcher-button-size) !important;
      border-radius: var(--chrome-pill-radius) !important;
    }
    moz-button[type="icon"]::part(button) {
      background-color: color-mix(in srgb, currentColor 18%, transparent) !important;
    }
    .bottom-actions {
      display: none !important;
    }
    moz-button[view="viewCustomizeSidebar"] {
      display: none !important;
    }
    moz-button[view="${VIEW}"] {
      order: 0 !important;
      margin: 0 !important;
    }
    moz-button[view="viewTabsSidebar"] { order: 1 !important; }
    moz-button[view="viewBookmarksSidebar"] { order: 2 !important; }
    moz-button[view="viewHistorySidebar"] { order: 3 !important; }
  `;

  function apply() {
    const sm = document.querySelector("sidebar-main");
    const sidebarBox = document.querySelector("#sidebar-box");
    if (!sm || !sm.shadowRoot || !sidebarBox) return false;
    const launcher = sm.parentElement;
    if (!launcher) return false;

    launcher.dataset.sideberyBottomLauncher = "true";
    const browser = document.querySelector("#browser");
    const bookmarksToolbar = document.querySelector("#PersonalToolbar");
    const inset =
      parseFloat(
        getComputedStyle(launcher).getPropertyValue(
          "--sidebery-launcher-inset",
        ),
      ) || 0;
    const syncPosition = () => {
      if (!browser) return;
      const browserRect = browser.getBoundingClientRect();
      const sidebarRect = sidebarBox.getBoundingClientRect();
      launcher.style.setProperty(
        "--sidebery-launcher-left",
        `${sidebarRect.left - browserRect.left + inset}px`,
      );
      launcher.style.setProperty(
        "--sidebery-launcher-width",
        `${sidebarRect.width - 2 * inset}px`,
      );
    };
    const syncBookmarksOffset = () => {
      const height = bookmarksToolbar?.getBoundingClientRect().height ?? 0;
      sidebarBox.style.setProperty(
        "--sidebery-bookmarks-toolbar-height",
        `${height}px`,
      );
    };
    syncPosition();
    syncBookmarksOffset();
    requestAnimationFrame(syncPosition);
    requestAnimationFrame(syncBookmarksOffset);
    if (!launcher._sideberyBottomResizeObserver) {
      launcher._sideberyBottomResizeObserver = new ResizeObserver(syncPosition);
      launcher._sideberyBottomResizeObserver.observe(sidebarBox);
    }
    if (bookmarksToolbar && !sidebarBox._sideberyBookmarksResizeObserver) {
      sidebarBox._sideberyBookmarksResizeObserver = new ResizeObserver(
        syncBookmarksOffset,
      );
      sidebarBox._sideberyBookmarksResizeObserver.observe(bookmarksToolbar);
    }
    const root = sm.shadowRoot;
    if (root._sideberyFirstSheet) return true;
    const sheet = new CSSStyleSheet();
    sheet.replaceSync(CSS);
    root.adoptedStyleSheets = [...root.adoptedStyleSheets, sheet];
    root._sideberyFirstSheet = sheet;
    return true;
  }

  if (apply()) return;

  // sidebar-main not ready yet; wait for it, then stop observing
  const obs = new MutationObserver(() => {
    if (apply()) obs.disconnect();
  });
  obs.observe(document.documentElement, { childList: true, subtree: true });
  setTimeout(() => obs.disconnect(), 20000);
})();

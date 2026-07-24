// ==UserScript==
// @name           compact-sidebar-panel
// @include        chrome://browser/content/sidebar/sidebar-syncedtabs.html
// @include        chrome://browser/content/sidebar/sidebar-history.html
// @include        chrome://browser/content/sidebar/sidebar-bookmarks.html
// @include        chrome://browser/content/places/bookmarksSidebar.xhtml
// ==/UserScript==

// Scoped tweaks for the native sidebar panels. fx-autoconfig injects this into
// each matched panel document at DOMContentLoaded, so document/window here are
// the panel's own. Needs userChromeJS.persistent_domcontent_callback = true so
// it re-runs each time a panel reloads, not just the first load.
(function () {
  // fx-autoconfig injects with the chrome window as the ambient global, so
  // reach the panel's own window explicitly. Sheets built from the wrong
  // window's CSSStyleSheet throw when adopted into the panel's shadow root.
  const win = document.defaultView;
  const root = document.documentElement;

  // Round the search box + moz-buttons (e.g. the header's options menu) in
  // every matched panel. These tokens inherit across shadow boundaries, and
  // the legacy bookmarks sidebar's #search-box is a moz-input-search that
  // reads them too.
  root.style.setProperty("--input-text-border-radius", "9999px");
  root.style.setProperty("--button-border-radius", "9999px");

  // Shift every matched panel down.
  root.style.boxSizing = "border-box";
  root.style.paddingTop = "25px";

  // The legacy bookmarks sidebar (bookmarksSidebar.xhtml) is a plain XUL doc
  // with no sidebar-* component, so it gets only the root tweaks above.
  if (win.location.href.endsWith("bookmarksSidebar.xhtml")) return;

  let attempts = 0;

  function apply() {
    const panel = document.querySelector(
      "sidebar-syncedtabs, sidebar-history, sidebar-bookmarks",
    );
    const panelRoot = panel?.openOrClosedShadowRoot;
    if (!panelRoot) {
      if (attempts++ < 120) win.requestAnimationFrame(apply);
      return;
    }

    // Hide the scrollbar in every matched panel.
    if (!panelRoot._compactSidebarScrollbarSheet) {
      const sheet = new win.CSSStyleSheet();
      sheet.replaceSync(`* { scrollbar-width: none !important; }`);
      panelRoot.adoptedStyleSheets = [...panelRoot.adoptedStyleSheets, sheet];
      panelRoot._compactSidebarScrollbarSheet = sheet;
    }

    // Bookmarks gets only the root-level shift/radius + scrollbar above.
    if (panel.localName === "sidebar-bookmarks") return;

    const headerRoot = panelRoot.querySelector(
      'sidebar-panel-header[view="viewTabsSidebar"], sidebar-panel-header[view="viewHistorySidebar"]',
    )?.openOrClosedShadowRoot;
    const heading = headerRoot?.querySelector(".sidebar-panel-heading");

    if (heading) {
      heading.style.setProperty("display", "none", "important");

      if (!panelRoot._compactSidebarPanelSheet) {
        const sheet = new win.CSSStyleSheet();
        sheet.replaceSync(`
          :host {
            --compact-sidebar-spacing: 4px;
          }

          .sidebar-panel {
            padding: var(--space-small) !important;
          }

          .sidebar-panel-scrollable-content {
            padding: var(--compact-sidebar-spacing) 0 0 !important;
            --size-item-large: 28px;
            --card-background-color: transparent;
            --card-border: none;
            --card-box-shadow: none;
            --card-border-radius: 0;
            --card-padding: 0;
            --card-padding-block: 0;
            --card-padding-inline: 0;
            --card-heading-padding-inline: var(--compact-sidebar-spacing);
            --card-gap: var(--compact-sidebar-spacing);
          }

          moz-card {
            margin-block-start: 2px !important;
            border: none !important;
            box-shadow: none !important;
            background: transparent !important;
          }

          moz-card::part(summary) {
            padding-block: var(--compact-sidebar-spacing) !important;
          }

          moz-card::part(moz-card-heading-wrapper) {
            padding-inline: var(--compact-sidebar-spacing) !important;
          }
        `);
        panelRoot.adoptedStyleSheets = [...panelRoot.adoptedStyleSheets, sheet];
        panelRoot._compactSidebarPanelSheet = sheet;
      }
      return;
    }

    if (attempts++ < 120) win.requestAnimationFrame(apply);
  }

  apply();
})();

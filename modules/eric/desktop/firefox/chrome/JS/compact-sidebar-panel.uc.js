// ==UserScript==
// @name           compact-sidebar-panel
// @include        chrome://browser/content/sidebar/sidebar-syncedtabs.html
// @include        chrome://browser/content/sidebar/sidebar-history.html
// @include        chrome://browser/content/sidebar/sidebar-bookmarks.html
// @include        chrome://browser/content/places/bookmarksSidebar.xhtml
// ==/UserScript==

// scoped tweaks for the native sidebar panels, injected per matched panel doc
// needs userChromeJS.persistent_domcontent_callback = true to re-run on reload
(function () {
  // use the panel's own window; a sheet from the chrome window's CSSStyleSheet
  // throws when adopted into the panel's shadow root
  const win = document.defaultView;
  const root = document.documentElement;

  // round the search box and moz-buttons; the tokens inherit across shadow
  // boundaries into every matched panel
  root.style.setProperty("--input-text-border-radius", "9999px");
  root.style.setProperty("--button-border-radius", "9999px");

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

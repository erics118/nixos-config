export class CompactSidebarPanelChild extends JSWindowActorChild {
  handleEvent(event) {
    if (event.type !== "DOMContentLoaded") return;

    const document = event.target;
    const window = document.defaultView;

    // Root-level tweaks for every matched panel (history/bookmarks/synced):
    // shift the whole panel down, and round the search box + moz-buttons (e.g.
    // the header's options menu). Both radii are tokens that inherit across the
    // components' shadow boundaries.
    const root = document.documentElement;
    root.style.boxSizing = "border-box";
    root.style.paddingTop = "25px";
    root.style.setProperty("--input-text-border-radius", "9999px");
    root.style.setProperty("--button-border-radius", "9999px");

    let attempts = 0;

    function apply() {
      const panel = document.querySelector(
        "sidebar-syncedtabs, sidebar-history, sidebar-bookmarks",
      );
      const panelRoot = panel?.openOrClosedShadowRoot;
      if (!panelRoot) {
        if (attempts++ < 120) window.requestAnimationFrame(apply);
        return;
      }

      // Hide the scrollbar in every matched panel.
      if (!panelRoot._compactSidebarScrollbarSheet) {
        const sheet = new window.CSSStyleSheet();
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
          const sheet = new window.CSSStyleSheet();
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
          panelRoot.adoptedStyleSheets = [
            ...panelRoot.adoptedStyleSheets,
            sheet,
          ];
          panelRoot._compactSidebarPanelSheet = sheet;
        }
        return;
      }

      if (attempts++ < 120) window.requestAnimationFrame(apply);
    }

    apply();
  }
}

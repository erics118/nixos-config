// urlbar-child-tab.uc.js
// Nest address-bar tabs into the Sidebery tree instead of dropping them at the
// end of the panel. Firefox normally opens urlbar tabs with no opener, so
// Sidebery has nothing to nest them under. We set the opener so Sidebery reads
// it as openerTabId and nests accordingly. Both open in the background so focus
// stays on the current tab.
//   Cmd+Enter        -> child of the current tab   (where === "tab")
//   Cmd+Shift+Enter  -> sibling of the current tab  (where === "tabshifted")

(function () {
  function hook() {
    const urlbar = window.gURLBar;
    if (!urlbar || typeof urlbar._loadURL !== "function") {
      setTimeout(hook, 300);
      return;
    }
    if (urlbar._childTabPatched) return;
    urlbar._childTabPatched = true;

    const orig = urlbar._loadURL.bind(urlbar);
    urlbar._loadURL = function (url, event, where, openParams = {}, ...rest) {
      if (where === "tab") {
        // child: opener is the current tab
        if (openParams.relatedToCurrent === undefined) {
          openParams.relatedToCurrent = true;
        }
      } else if (where === "tabshifted") {
        // sibling: opener is the current tab's parent, if it has one
        const parent = window.gBrowser.selectedTab.openerTab;
        if (parent && openParams.openerBrowser === undefined) {
          openParams.openerBrowser = parent.linkedBrowser;
        }
      }
      if (
        (where === "tab" || where === "tabshifted") &&
        openParams.inBackground === undefined
      ) {
        openParams.inBackground = true;
      }
      return orig(url, event, where, openParams, ...rest);
    };
  }
  hook();
})();

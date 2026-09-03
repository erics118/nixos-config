// urlbar-enter-tabs.uc.js
// Cmd+Enter opens a background tab, Cmd+Shift+Enter a background child tab
// relatedToCurrent sets the opener so Sidebery nests it as a child

(function () {
  let tries = 0;
  function hook() {
    const urlbar = window.gURLBar;
    const ctrl = urlbar?.controller;
    if (
      !urlbar ||
      !ctrl ||
      typeof urlbar.handleNavigation !== "function" ||
      typeof ctrl.loadURL !== "function"
    ) {
      if (++tries > 40) {
        console.error("urlbar-enter-tabs: gURLBar hooks not found");
        return;
      }
      setTimeout(hook, 300);
      return;
    }
    if (urlbar._enterTabsPatched) return;
    urlbar._enterTabsPatched = true;

    const origNav = urlbar.handleNavigation.bind(urlbar);
    urlbar.handleNavigation = function (opts) {
      const prev = urlbar._enterEvent;
      urlbar._enterEvent = opts?.event || null;
      try {
        return origNav(opts);
      } finally {
        urlbar._enterEvent = prev;
      }
    };

    const origLoad = ctrl.loadURL.bind(ctrl);
    ctrl.loadURL = function (loadData) {
      const e = urlbar._enterEvent;
      if (
        e &&
        KeyboardEvent.isInstance(e) &&
        e.key === "Enter" &&
        e.metaKey &&
        !e.altKey &&
        loadData?.params
      ) {
        loadData.params.inBackground = true;
        if (e.shiftKey) {
          loadData.params.relatedToCurrent = true;
        }
      }
      return origLoad(loadData);
    };
  }
  hook();
})();

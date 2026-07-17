// kill-tab-shortcuts.uc.js
// Strip Firefox's native tab-switching keys (Ctrl+Tab, Ctrl+1-9, show-all-tabs)
// so Sidebery owns them, and keep Alt+PgUp/PgDn tab nav in the chrome so content
// pages can't swallow it.

(function () {
  const badCommands = [
    "Browser:NextTab",
    "Browser:PrevTab",
    "Browser:ShowAllTabs",
  ];
  const badIds = [
    "key_selectTab1",
    "key_selectTab2",
    "key_selectTab3",
    "key_selectTab4",
    "key_selectTab5",
    "key_selectTab6",
    "key_selectTab7",
    "key_selectTab8",
    "key_selectLastTab",
    "key_showAllTabs",
  ];

  function nukeKey(el) {
    if (!el || el.tagName !== "key") return;
    const cmd = el.getAttribute("command");
    if (badIds.includes(el.id) || badCommands.includes(cmd)) {
      el.remove();
      console.log("kill-tab-shortcuts: removed", el.id || cmd);
    }
  }

  // remove anything already present
  document.querySelectorAll("key").forEach(nukeKey);

  // catch keys ctrlTab inserts lazily on first real use
  new MutationObserver((muts) => {
    for (const m of muts) {
      for (const node of m.addedNodes) {
        if (node.nodeType !== 1) continue;
        if (node.tagName === "key") nukeKey(node);
        node.querySelectorAll?.("key").forEach(nukeKey);
      }
    }
  }).observe(document.documentElement, { childList: true, subtree: true });

  // neutralize the object too, so it can't rebuild state
  function killCtrlTab() {
    if (typeof ctrlTab !== "undefined") {
      try {
        ctrlTab.uninit?.();
      } catch (e) {}
      ctrlTab.init = function () {};
      ctrlTab.readPref = function () {};
    } else {
      setTimeout(killCtrlTab, 300);
    }
  }
  killCtrlTab();

  // last-resort: block the event outright regardless of what handles it
  window.addEventListener(
    "keydown",
    (e) => {
      if (e.key === "Tab" && e.ctrlKey && !e.metaKey && !e.altKey) {
        e.stopImmediatePropagation();
        e.preventDefault();
        return;
      }

      // Keep these tab-navigation keys in browser chrome. Content pages (for
      // example GitHub's keyboard handler) therefore cannot consume them.
      if (
        e.altKey &&
        !e.ctrlKey &&
        !e.metaKey &&
        (e.key === "PageUp" || e.key === "PageDown")
      ) {
        e.stopImmediatePropagation();
        e.preventDefault();
        gBrowser.tabContainer.advanceSelectedTab(
          e.key === "PageDown" ? 1 : -1,
          true,
        );
      }
    },
    true,
  );
})();

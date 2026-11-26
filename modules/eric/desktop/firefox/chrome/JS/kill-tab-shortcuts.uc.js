// kill-tab-shortcuts.uc.js
// strip Firefox's native tab-switching keys (Ctrl+Tab, Cmd+1-9, show-all-tabs)
// so Sidebery owns them; keep Alt+PgUp/PgDn tab nav in the chrome
// mark Sidebery's Ctrl+Alt+PgUp/PgDn keys reserved, so pages like GitHub can't eat them

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
    }
  }

  // reserved keys fire before the page sees the keydown
  const sideberyKeyset = "ext-keyset-id-sidebery-fork_erics118";
  function reserveSideberyKey(el) {
    if (el?.tagName !== "key" || el.parentNode?.id !== sideberyKeyset) return;
    const code = el.getAttribute("keycode");
    if (code === "VK_PAGE_UP" || code === "VK_PAGE_DOWN") {
      el.setAttribute("reserved", "true");
    }
  }

  // remove anything already present
  document.querySelectorAll("key").forEach((el) => {
    nukeKey(el);
    reserveSideberyKey(el);
  });

  // catch keys ctrlTab inserts lazily on first real use
  new MutationObserver((muts) => {
    for (const m of muts) {
      for (const node of m.addedNodes) {
        if (node.nodeType !== 1) continue;
        for (const el of [node, ...(node.querySelectorAll?.("key") ?? [])]) {
          nukeKey(el);
          reserveSideberyKey(el);
        }
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

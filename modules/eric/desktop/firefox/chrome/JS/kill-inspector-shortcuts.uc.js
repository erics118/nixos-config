// kill-inspector-shortcuts.uc.js
// Remove the two DevTools inspector keys DevToolsStartup injects into
// devtoolsKeyset: key_inspector (Cmd+Alt+C) and key_inspectorMac (Cmd+Shift+C).

(function () {
  const badIds = ["key_inspector", "key_inspectorMac"];

  function nukeKey(el) {
    if (el && el.tagName === "key" && badIds.includes(el.id)) {
      el.remove();
    }
  }

  // remove anything already present
  badIds.forEach((id) => nukeKey(document.getElementById(id)));

  // the devtools keyset is attached lazily on first devtools use
  new MutationObserver((muts) => {
    for (const m of muts) {
      for (const node of m.addedNodes) {
        if (node.nodeType !== 1) continue;
        if (node.tagName === "key") nukeKey(node);
        node.querySelectorAll?.("key").forEach(nukeKey);
      }
    }
  }).observe(document.documentElement, { childList: true, subtree: true });
})();
